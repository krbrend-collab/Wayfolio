import assert from 'node:assert/strict';
import {mkdtemp, readFile} from 'node:fs/promises';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {CampaignStateService, WRITE_CLASSES} from './campaign-state-service.mjs';

const directory = await mkdtemp(join(tmpdir(), 'wayfolio-campaign-state-'));
const statePath = join(directory, 'campaign-registry.json');
const seed = JSON.parse(await readFile(new URL('./content/shared-campaign-first-sync.json', import.meta.url), 'utf8'));
const service = new CampaignStateService({path:statePath, seed, now:() => '2026-09-02T12:00:00.000Z'});
await service.initialize();

const dryRun = service.firstSync({dryRun:true, sourceRevision:'sync-doc-wf-082'});
assert.equal(dryRun.can_cut_over, true, 'explicitly recorded unknown values are complete checkpoint facts');
assert.equal(dryRun.would_write_legacy_campaign_ledger, false, 'dry run must not dual-write the old ledger');
assert.ok(dryRun.reused_character_ids.includes('character_renn_hazel'));
assert.deepEqual(dryRun.unresolved_fields, []);
assert.equal(seed.shared_state.checkpoint.source_revision, seed.source_revision,
  'the checkpoint must remain aligned with the current first-sync source revision');
assert.equal(service.status().operational_source, 'legacy_campaign_ledger');

const cutoverDirectory = await mkdtemp(join(tmpdir(), 'wayfolio-campaign-cutover-'));
const cutoverService = new CampaignStateService({path:join(cutoverDirectory, 'registry.json'), seed,
  now:() => '2026-09-02T12:00:00.000Z'});
await cutoverService.initialize();
const cutover = await cutoverService.commitFirstSync({sourceRevision:'verified-checkpoint', currentStoryTime:'Hemlock evening',
  sharedLocation:'Briar & Bough, Hemlock', confirmedCharacters:{
    character_renn_hazel:{current_location:'Briar & Bough, Hemlock', hp:{current:10, maximum:10}, conditions:[], sync_status:'CONFIRMED'},
    character_yugen:{current_location:'Briar & Bough, Hemlock'},
  }});
assert.equal(cutover.can_cut_over, true);
assert.equal(cutover.state.operational_source, 'campaign_state_registry');
assert.equal(cutover.state.cutover_complete, true);
assert.equal(cutover.state.change_log[0].status, 'FIRST_SYNC');

const protectedResult = await service.transact({idempotencyKey:'protected-1', actor:{role:'host'},
  contentClass:WRITE_CLASSES.PROTECTED_MASTER, collection:'records', key:'protected_manifest', value:{changed:true}});
assert.equal(protectedResult.reason, 'protected_content');

const crossPlayer = await service.transact({idempotencyKey:'cross-player-1', actor:{role:'player', owner_id:'kevin'},
  contentClass:WRITE_CLASSES.PLAYER_MUTABLE, ownerID:'james', collection:'characters', key:'character_yugen', value:{choice:'leave'}});
assert.equal(crossPlayer.reason, 'player_ownership_required');

const privateResult = await service.transact({idempotencyKey:'secret-1', actor:{role:'dm'},
  contentClass:WRITE_CLASSES.GM_PRIVATE, collection:'shared_state', key:'unrevealed_motive', value:'secret'});
assert.equal(privateResult.reason, 'gm_private_storage_required');
assert.equal(service.projection({role:'screen'}).unrevealed_motive, undefined);
assert.equal((await readFile(statePath, 'utf8')).includes('unrevealed_motive'), false,
  'even the identity of a GM-private fact must not enter the player-shared registry');

const selfUpdate = await service.transact({idempotencyKey:'self-1', actor:{role:'player', owner_id:'kevin'},
  contentClass:WRITE_CLASSES.PLAYER_MUTABLE, ownerID:'kevin', collection:'characters', key:'character_renn_hazel',
  value:{...seed.characters.character_renn_hazel, conditions:['inspired']}, expectedRevision:service.status().revision});
assert.equal(selfUpdate.status, 'COMMITTED');
const replay = await service.transact({idempotencyKey:'self-1', actor:{role:'player', owner_id:'kevin'},
  contentClass:WRITE_CLASSES.PLAYER_MUTABLE, ownerID:'kevin', collection:'characters', key:'character_renn_hazel', value:{conditions:[]}});
assert.equal(replay.replayed, true);
assert.equal(replay.revision, selfUpdate.revision, 'idempotent replay must not create another revision');

const confirmed = await service.transact({idempotencyKey:'shared-1', actor:{role:'dm'},
  contentClass:WRITE_CLASSES.SHARED_MUTABLE, collection:'shared_state', key:'weather', value:'clear',
  expectedRevision:service.status().revision});
const conflict = await service.transact({idempotencyKey:'shared-2', actor:{role:'dm'},
  contentClass:WRITE_CLASSES.SHARED_MUTABLE, collection:'shared_state', key:'weather', value:'rain',
  expectedRevision:confirmed.revision - 1, evidence:'competing checkpoint'});
assert.equal(conflict.status, 'REVIEW');
assert.equal(service.projection({role:'dm'}).shared_state.weather, 'clear', 'review must preserve confirmed state');
const beforeResolve = service.projection({role:'dm'}).change_log;
assert.ok(beforeResolve.some(row => row.status === 'REVIEW' && row.conflict_id === conflict.conflict_id));
await service.resolveConflict({idempotencyKey:'resolve-1', conflictID:conflict.conflict_id, actor:{role:'dm', id:'dm'}, value:'rain'});
const afterResolve = service.projection({role:'dm'});
assert.equal(afterResolve.shared_state.weather, 'rain');
assert.ok(afterResolve.change_log.some(row => row.status === 'RESOLVED' && row.conflict_id === conflict.conflict_id));
assert.ok(afterResolve.change_log.some(row => row.status === 'REVIEW' && row.conflict_id === conflict.conflict_id),
  'resolution must not erase the original review history');

const screenProjection = service.projection({role:'screen'});
assert.equal(screenProjection.characters, undefined, 'shared iPad must not receive player-private character state');
assert.equal(screenProjection.change_log, undefined, 'shared iPad must not receive review data');
const rennProjection = service.projection({role:'player', ownerID:'kevin'});
assert.deepEqual(Object.keys(rennProjection.characters), ['character_renn_hazel']);
assert.equal(rennProjection.change_log, undefined);

await service.transact({idempotencyKey:'asset-review-1', actor:{role:'host'}, contentClass:WRITE_CLASSES.ASSET_VERSIONED,
  collection:'assets', key:'character_renn_hazel', value:{asset_id:'asset_candidate', status:'IN_REVIEW'},
  expectedRevision:service.status().revision});
assert.equal(service.projection({role:'screen'}).assets.character_renn_hazel.length, 0,
  'asset review state must not reach the shared iPad');
assert.equal(service.projection({role:'dm'}).assets.character_renn_hazel.length, 1);

console.log('WF-076/077 F33-F36 campaign state, ownership, conflict, privacy, and no-dual-write tests passed.');
