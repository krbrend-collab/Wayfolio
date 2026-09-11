import {mkdir, readFile, rename, writeFile} from 'node:fs/promises';
import {dirname} from 'node:path';
import {randomUUID} from 'node:crypto';

export const WRITE_CLASSES = Object.freeze({
  PROTECTED_MASTER:'PROTECTED_MASTER',
  PLAYER_MUTABLE:'PLAYER_MUTABLE',
  SHARED_MUTABLE:'SHARED_MUTABLE',
  APPEND_ONLY:'APPEND_ONLY',
  ASSET_VERSIONED:'ASSET_VERSIONED',
  ARCHIVE_ONLY:'ARCHIVE_ONLY',
  GM_PRIVATE:'GM_PRIVATE',
});

function clone(value) {
  return structuredClone(value);
}

function canonicalSeed(seed) {
  return {
    schema:'wayfolio.campaign-state-registry.v1',
    campaign_id:seed.campaign_id,
    revision:0,
    sync_status:seed.source_status || 'READY_FOR_FIRST_SYNC',
    operational_source:'legacy_campaign_ledger',
    cutover_complete:false,
    current_story_time:seed.current_story_time ?? null,
    shared_location:seed.shared_location ?? null,
    active_session_id:seed.active_session_id ?? null,
    characters:clone(seed.characters || {}),
    records:clone(seed.records || {}),
    shared_state:clone(seed.shared_state || {}),
    append_only:clone(seed.append_only || {}),
    assets:clone(seed.assets || {}),
    change_log:[],
    processed_transactions:{},
  };
}

function actorCanControlPlayerState(actor, ownerID) {
  return actor?.role === 'dm' || actor?.role === 'host'
    || (actor?.role === 'player' && actor?.owner_id === ownerID);
}

function publicChange(change) {
  if (!change || typeof change !== 'object' || Array.isArray(change)) return change;
  const {gm_private, ...safe} = change;
  return safe;
}

export class CampaignStateService {
  constructor({path, seed, now = () => new Date().toISOString()}) {
    if (!path) throw new Error('Campaign State service requires a persistence path.');
    if (!seed?.campaign_id) throw new Error('Campaign State service requires a campaign seed.');
    this.path = path;
    this.seed = clone(seed);
    this.now = now;
    this.state = null;
  }

  async initialize() {
    try {
      this.state = JSON.parse(await readFile(this.path, 'utf8'));
    } catch {
      this.state = canonicalSeed(this.seed);
      await this.#persist();
    }
    return this.status();
  }

  status() {
    return {
      campaign_id:this.state.campaign_id,
      revision:this.state.revision,
      sync_status:this.state.sync_status,
      operational_source:this.state.operational_source,
      cutover_complete:this.state.cutover_complete,
      unresolved_fields:this.#unresolvedFields(),
    };
  }

  firstSync({dryRun = true, currentStoryTime, sharedLocation, confirmedCharacters = {}, sourceRevision = null} = {}) {
    const candidate = canonicalSeed(this.seed);
    candidate.current_story_time = currentStoryTime ?? candidate.current_story_time;
    candidate.shared_location = sharedLocation ?? candidate.shared_location;
    for (const [characterID, confirmed] of Object.entries(confirmedCharacters)) {
      if (!candidate.characters[characterID]) throw new Error(`First sync cannot invent character ID: ${characterID}`);
      candidate.characters[characterID] = {...candidate.characters[characterID], ...clone(confirmed), character_id:characterID};
    }
    const unresolved = this.#unresolvedFields(candidate);
    const canCutOver = unresolved.length === 0;
    const result = {
      dry_run:dryRun,
      source_revision:sourceRevision,
      campaign_id:candidate.campaign_id,
      reused_character_ids:Object.keys(candidate.characters),
      reused_record_ids:Object.keys(candidate.records),
      unresolved_fields:unresolved,
      can_cut_over:canCutOver,
      would_write_legacy_campaign_ledger:false,
    };
    if (dryRun) return result;
    if (!canCutOver) throw new Error(`First sync cannot cut over with unresolved fields: ${unresolved.join(', ')}`);
    this.state = candidate;
    this.state.revision = 1;
    this.state.sync_status = 'SYNCED';
    this.state.operational_source = 'campaign_state_registry';
    this.state.cutover_complete = true;
    this.state.change_log.push(this.#log('FIRST_SYNC', {
      source_revision:sourceRevision,
      imported_character_ids:Object.keys(candidate.characters),
      imported_record_ids:Object.keys(candidate.records),
    }));
    return {...result, dry_run:false, can_cut_over:true, state:clone(this.state)};
  }

  async commitFirstSync(options = {}) {
    const result = this.firstSync({...options, dryRun:false});
    await this.#persist();
    return result;
  }

  async transact({idempotencyKey, actor, contentClass, ownerID = null, collection = 'shared_state', key, value,
    expectedRevision = this.state.revision, evidence = null}) {
    if (!idempotencyKey) throw new Error('A stable idempotency key is required.');
    if (this.state.processed_transactions[idempotencyKey]) {
      return {...clone(this.state.processed_transactions[idempotencyKey]), replayed:true};
    }
    if (!Object.values(WRITE_CLASSES).includes(contentClass)) throw new Error(`Unknown write class: ${contentClass}`);
    if ([WRITE_CLASSES.PROTECTED_MASTER, WRITE_CLASSES.ARCHIVE_ONLY].includes(contentClass)) {
      return this.#reject(idempotencyKey, 'protected_content', {contentClass, collection, key});
    }
    if (contentClass === WRITE_CLASSES.GM_PRIVATE) {
      return {ok:false, status:'REJECTED', reason:'gm_private_storage_required', revision:this.state.revision};
    }
    if (contentClass === WRITE_CLASSES.PLAYER_MUTABLE && !actorCanControlPlayerState(actor, ownerID)) {
      return this.#reject(idempotencyKey, 'player_ownership_required', {contentClass, collection, key, ownerID});
    }
    if (contentClass === WRITE_CLASSES.SHARED_MUTABLE && !['dm', 'host'].includes(actor?.role)) {
      return this.#reject(idempotencyKey, 'shared_session_authority_required', {contentClass, collection, key});
    }
    if (expectedRevision !== this.state.revision) {
      const conflictID = `conflict:${randomUUID()}`;
      const record = this.#log('REVIEW', {conflict_id:conflictID, content_class:contentClass, collection, key,
        owner_id:ownerID,
        confirmed_value:clone(this.state[collection]?.[key] ?? null), proposed_value:clone(value), evidence,
        expected_revision:expectedRevision, actual_revision:this.state.revision});
      this.state.change_log.push(record);
      this.state.revision += 1;
      const result = {ok:false, status:'REVIEW', conflict_id:conflictID, revision:this.state.revision};
      this.state.processed_transactions[idempotencyKey] = result;
      await this.#persist();
      return clone(result);
    }
    if (contentClass === WRITE_CLASSES.APPEND_ONLY) {
      this.state.append_only[collection] ||= [];
      this.state.append_only[collection].push(clone(value));
    } else if (contentClass === WRITE_CLASSES.ASSET_VERSIONED) {
      this.state.assets[key] ||= [];
      this.state.assets[key].push({...clone(value), status:value?.status || 'IN_REVIEW'});
    } else {
      this.state[collection] ||= {};
      this.state[collection][key] = clone(value);
    }
    this.state.revision += 1;
    this.state.change_log.push(this.#log('COMMITTED', {content_class:contentClass, collection, key,
      owner_id:ownerID, value:publicChange(clone(value)), evidence}));
    const result = {ok:true, status:'COMMITTED', revision:this.state.revision};
    this.state.processed_transactions[idempotencyKey] = result;
    await this.#persist();
    return clone(result);
  }

  async resolveConflict({idempotencyKey, conflictID, actor, value}) {
    if (!['dm', 'host', 'player'].includes(actor?.role)) throw new Error('Authorized resolution actor required.');
    const review = this.state.change_log.find(row => row.status === 'REVIEW' && row.conflict_id === conflictID);
    if (!review) throw new Error('Review conflict was not found.');
    if (actor.role === 'player' && actor.owner_id !== review.owner_id) {
      throw new Error('Owning player or shared-session authority must resolve this conflict.');
    }
    this.state[review.collection] ||= {};
    this.state[review.collection][review.key] = clone(value);
    this.state.revision += 1;
    this.state.change_log.push(this.#log('RESOLVED', {conflict_id:conflictID, collection:review.collection,
      key:review.key, resolved_value:clone(value), resolved_by:actor.id || actor.owner_id || actor.role}));
    const result = {ok:true, status:'RESOLVED', revision:this.state.revision};
    this.state.processed_transactions[idempotencyKey] = result;
    await this.#persist();
    return clone(result);
  }

  projection({role, ownerID = null}) {
    const approvedAssets = Object.fromEntries(Object.entries(this.state.assets).map(([key, versions]) => [key,
      versions.filter(version => ['APPROVED', 'CURRENT', 'APPROVED_CURRENT'].includes(version.status))]));
    const base = {
      campaign_id:this.state.campaign_id,
      revision:this.state.revision,
      sync_status:this.state.sync_status,
      current_story_time:this.state.current_story_time,
      shared_location:this.state.shared_location,
      active_session_id:this.state.active_session_id,
      records:clone(this.state.records),
      shared_state:clone(this.state.shared_state),
      append_only:clone(this.state.append_only),
      assets:clone(approvedAssets),
    };
    if (role === 'screen') return base;
    if (role === 'player') {
      base.characters = Object.fromEntries(Object.entries(this.state.characters)
        .filter(([, character]) => character.owner_id === ownerID).map(([id, character]) => [id, clone(character)]));
      return base;
    }
    if (role === 'dm') return {...base, characters:clone(this.state.characters), assets:clone(this.state.assets),
      change_log:clone(this.state.change_log)};
    throw new Error(`Unsupported campaign projection role: ${role}`);
  }

  #unresolvedFields(state = this.state) {
    const unresolved = [];
    if (!state.current_story_time) unresolved.push('current_story_time');
    if (!state.shared_location) unresolved.push('shared_location');
    for (const [id, character] of Object.entries(state.characters || {})) {
      for (const field of ['current_location', 'hp', 'conditions']) {
        if (character[field] == null) unresolved.push(`characters.${id}.${field}`);
      }
    }
    return unresolved;
  }

  #log(status, detail) {
    return {change_id:`change:${randomUUID()}`, status, recorded_at:this.now(), ...detail};
  }

  async #reject(idempotencyKey, reason, detail) {
    const result = {ok:false, status:'REJECTED', reason, revision:this.state.revision};
    this.state.processed_transactions[idempotencyKey] = result;
    this.state.change_log.push(this.#log('REJECTED', {...detail, reason}));
    await this.#persist();
    return clone(result);
  }

  async #persist() {
    await mkdir(dirname(this.path), {recursive:true});
    const temporary = `${this.path}.tmp`;
    await writeFile(temporary, `${JSON.stringify(this.state, null, 2)}\n`);
    await rename(temporary, this.path);
  }
}
