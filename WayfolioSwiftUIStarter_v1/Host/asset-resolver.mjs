import {createHash} from 'node:crypto';
import {mkdir, readFile, rename, stat, writeFile} from 'node:fs/promises';
import {join, resolve} from 'node:path';

const DEFAULT_MANIFEST_ID = '1OX0wO4aVY0E8rJc2-8fDj8rvWf3z3QB0XNosIe8dcCA';
const MAX_ASSET_BYTES = 48 * 1024 * 1024;

const clean = value => String(value ?? '').trim();
const key = value => clean(value).toUpperCase().replaceAll(/[^A-Z0-9]+/g, '_').replaceAll(/^_|_$/g, '');
const split = value => clean(value).split(/[|,;]+/).map(key).filter(Boolean);
const digest = value => createHash('sha256').update(value).digest('hex');

const ASSET_ROLE_ALIASES = Object.freeze({
  SHARED_IPAD_BACKGROUND: 'SHARED_IPAD_LOCATION_BACKGROUND',
});

const canonicalAssetRole = value => ASSET_ROLE_ALIASES[key(value)] || key(value);

// Campaign State owns location identity. Group 8 `hemlock.*` identifiers are
// visual-routing aliases only and must never create a second world record.
export const LOCATION_ASSET_ID_CROSSWALK = Object.freeze({
  LOCATION_MAIN_SHRINE_GROVE: ['HEMLOCK_MAIN_SHRINE_GROVE'],
  LOCATION_QUIET_SHRINE: ['HEMLOCK_QUIET_SHRINE', 'HEMLOCK_GARDEN_SHRINE', 'HEMLOCK_LOCATION_04'],
  LOCATION_WATER_GARDEN_SACRED_SPRING: ['HEMLOCK_WATER_GARDEN_SACRED_SPRING'],
  LOCATION_COMMONS_MARKET_PLAZA: ['HEMLOCK_COMMONS_MARKET_PLAZA', 'HEMLOCK_COMMONS_PLAZA', 'HEMLOCK_LOCATION_02'],
  LOCATION_COMMONS_EXCHANGE_HALL: ['HEMLOCK_COMMONS_EXCHANGE_HALL'],
  LOCATION_HERBAL_WORKSHOP: ['LOCATION_HEMLOCK_HERBAL_WORKSHOP', 'HEMLOCK_HERBAL_WORKSHOP'],
  LOCATION_CREATURE_CARE_CENTER: ['LOCATION_HEMLOCK_CREATURE_CARE_CENTER', 'HEMLOCK_CREATURE_CARE_CENTER'],
  LOCATION_ROOT_AND_KETTLE: ['HEMLOCK_ROOT_AND_KETTLE', 'HEMLOCK_ROOT_KETTLE', 'HEMLOCK_LOCATION_20'],
  LOCATION_WAYHOUSE: ['HEMLOCK_WAYHOUSE'],
  LOCATION_WAYFARERS_HALL: ['HEMLOCK_WAYFARERS_HALL'],
  LOCATION_RENN_HOME: ['HEMLOCK_RENN_HOME'],
});

const LOCATION_CANONICAL_BY_ALIAS = new Map(Object.entries(LOCATION_ASSET_ID_CROSSWALK)
  .flatMap(([canonical, aliases]) => [canonical, ...aliases].map(alias => [key(alias), canonical])));

function canonicalSubjectID(subjectType, subjectID) {
  const normalized = key(subjectID);
  return key(subjectType) === 'LOCATION' ? (LOCATION_CANONICAL_BY_ALIAS.get(normalized) || normalized) : normalized;
}

function parseCSV(source) {
  const rows = []; let row = []; let cell = ''; let quoted = false;
  for (let index = 0; index < source.length; index += 1) {
    const character = source[index];
    if (quoted) {
      if (character === '"' && source[index + 1] === '"') { cell += '"'; index += 1; }
      else if (character === '"') quoted = false;
      else cell += character;
    } else if (character === '"') quoted = true;
    else if (character === ',') { row.push(cell); cell = ''; }
    else if (character === '\n') { row.push(cell.replace(/\r$/, '')); rows.push(row); row = []; cell = ''; }
    else cell += character;
  }
  if (cell || row.length) { row.push(cell.replace(/\r$/, '')); rows.push(row); }
  return rows;
}

function rowsToRecords(rows) {
  const headers = (rows[0] || []).map(value => clean(value));
  return rows.slice(1).filter(row => row.some(Boolean)).map(row => Object.fromEntries(headers.map((header, index) => [header, clean(row[index])])));
}

function normalizeManifestPayload(payload) {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.assets)) return payload.assets;
  if (Array.isArray(payload?.values)) return rowsToRecords(payload.values);
  throw new Error('The asset manifest did not contain asset rows.');
}

export class DriveAssetManifestSource {
  constructor({fetchImpl = globalThis.fetch, manifestID = DEFAULT_MANIFEST_ID,
    manifestURL = process.env.WAYFOLIO_ASSET_MANIFEST_URL || '',
    accessToken = process.env.WAYFOLIO_DRIVE_ACCESS_TOKEN || '',
    snapshotPath = '', refreshMilliseconds = 60_000} = {}) {
    this.fetch = fetchImpl; this.manifestID = manifestID; this.manifestURL = manifestURL;
    this.accessToken = accessToken; this.snapshotPath = snapshotPath;
    this.refreshMilliseconds = refreshMilliseconds; this.current = null; this.refreshPromise = null;
  }

  async snapshot({force = false} = {}) {
    if (!force && this.current && Date.now() - this.current.fetched_at_ms < this.refreshMilliseconds) return this.current;
    if (this.refreshPromise) return this.refreshPromise;
    this.refreshPromise = this.#refresh().finally(() => { this.refreshPromise = null; });
    return this.refreshPromise;
  }

  async #refresh() {
    try {
      const response = await this.fetch(this.#manifestEndpoint(), {headers:this.accessToken ? {authorization:`Bearer ${this.accessToken}`} : {}});
      if (!response.ok) throw new Error(`manifest request returned ${response.status}`);
      const contentType = response.headers.get('content-type') || '';
      const rows = contentType.includes('json')
        ? normalizeManifestPayload(await response.json())
        : rowsToRecords(parseCSV(await response.text()));
      if (!rows.length) throw new Error('the current manifest has no asset rows');
      if (!Object.hasOwn(rows[0], 'asset_id') || !Object.hasOwn(rows[0], 'status')) {
        throw new Error('the Drive response was not the Visual Asset Manifest ASSETS table');
      }
      const revision = response.headers.get('etag') || response.headers.get('last-modified')
        || digest(JSON.stringify(rows.map(row => [row.asset_id, row.version, row.status, row.canon_relationship, row.storage_file_id_or_key]))).slice(0, 20);
      this.current = {authority:'DRIVE_VISUAL_ASSET_MANIFEST', manifest_id:this.manifestID, revision, rows,
        fetched_at:new Date().toISOString(), fetched_at_ms:Date.now(), source:'drive'};
      if (this.snapshotPath) await atomicJSON(this.snapshotPath, this.current);
      return this.current;
    } catch (error) {
      if (this.current) return {...this.current, refresh_warning:error.message};
      if (this.snapshotPath) {
        try {
          const saved = JSON.parse(await readFile(this.snapshotPath, 'utf8'));
          this.current = {...saved, fetched_at_ms:0, source:'drive_manifest_last_known_good', refresh_warning:error.message};
          return this.current;
        } catch {}
      }
      throw new Error(`Current Drive asset authority is unavailable: ${error.message}`);
    }
  }

  #manifestEndpoint() {
    if (this.manifestURL) return this.manifestURL;
    if (this.accessToken) return `https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(this.manifestID)}/values/ASSETS!A:AP?majorDimension=ROWS`;
    return `https://docs.google.com/spreadsheets/d/${encodeURIComponent(this.manifestID)}/gviz/tq?tqx=out:csv&sheet=ASSETS`;
  }
}

export class HostAssetResolver {
  constructor({manifestSource, cacheDirectory, fetchImpl = globalThis.fetch, publicPrefix = '/api/assets/content',
    accessToken = process.env.WAYFOLIO_DRIVE_ACCESS_TOKEN || ''} = {}) {
    if (!manifestSource || !cacheDirectory) throw new Error('Asset resolver requires a manifest authority and cache directory.');
    this.manifestSource = manifestSource; this.cacheDirectory = resolve(cacheDirectory);
    this.fetch = fetchImpl; this.publicPrefix = publicPrefix; this.accessToken = accessToken;
    this.issued = new Map();
  }

  async resolve(request) {
    const semantic = normalizeSemanticRequest(request);
    let manifest;
    try { manifest = await this.manifestSource.snapshot(); }
    catch (error) { return {state:'fallback', reason:'manifest_unavailable', message:error.message, fallback:semantic.fallback}; }
    const eligible = manifest.rows.filter(row => isEligible(row, semantic));
    const selected = eligible.sort(compareAssets)[0];
    if (!selected) return {state:'fallback', reason:'no_eligible_current_asset', manifest_revision:manifest.revision, fallback:semantic.fallback};
    try {
      return await this.#materialize(selected, manifest, semantic);
    } catch (error) {
      const lastKnownGood = await this.#lastKnownGood(semantic, manifest);
      if (lastKnownGood) return {...lastKnownGood, state:'last_known_good', warning:error.message};
      return {state:'fallback', reason:'asset_download_failed', message:error.message,
        manifest_revision:manifest.revision, fallback:semantic.fallback};
    }
  }

  async content(token) {
    const issued = this.issued.get(clean(token));
    if (!issued) return null;
    try {
      const info = await stat(issued.path);
      if (!info.isFile()) return null;
      return {...issued, size:info.size};
    } catch { return null; }
  }

  async #materialize(asset, manifest, semantic) {
    const assetID = clean(asset.asset_id); const version = clean(asset.version) || '1';
    const revision = digest(`${assetID}\0${version}\0${manifest.revision}\0${clean(asset.content_hash)}`).slice(0, 24);
    const extension = extensionFor(asset.mime_type, asset.storage_url || asset.source_reference);
    const directory = join(this.cacheDirectory, digest(assetID).slice(0, 16));
    const path = join(directory, `${revision}${extension}`);
    let source = 'host_cache';
    try { if (!(await stat(path)).isFile()) throw new Error('not a file'); }
    catch { await this.#download(asset, path); source = 'drive_download'; }
    const token = digest(`${assetID}\0${version}\0${revision}`).slice(0, 32);
    this.issued.set(token, {path, mime_type:clean(asset.mime_type) || mimeFromExtension(extension), etag:clean(asset.content_hash) || revision,
      asset_id:assetID, version, revision});
    await this.#remember(semantic, {asset_id:assetID, version, revision, path, mime_type:clean(asset.mime_type), content_hash:clean(asset.content_hash)});
    return descriptor(asset, manifest, token, revision, source, this.publicPrefix);
  }

  async #download(asset, destination) {
    const url = storageURL(asset, this.accessToken);
    if (!url) throw new Error(`Approved asset ${asset.asset_id} has no valid Drive storage reference.`);
    const response = await this.fetch(url, {headers:this.accessToken ? {authorization:`Bearer ${this.accessToken}`} : {}});
    if (!response.ok) throw new Error(`Asset download returned ${response.status}.`);
    const bytes = Buffer.from(await response.arrayBuffer());
    if (!bytes.length || bytes.length > MAX_ASSET_BYTES) throw new Error('Asset bytes were empty or exceeded the Host safety limit.');
    const declared = clean(asset.content_hash).replace(/^sha256:/i, '').toLowerCase();
    if (declared && /^[a-f0-9]{64}$/.test(declared) && digest(bytes) !== declared) throw new Error('Asset checksum did not match the approved manifest.');
    const receivedType = clean(response.headers.get('content-type')).split(';')[0];
    const expectedType = clean(asset.mime_type).split(';')[0];
    if (receivedType && expectedType && receivedType !== expectedType) throw new Error('Downloaded asset type did not match the approved manifest.');
    await mkdir(resolve(destination, '..'), {recursive:true});
    const temporary = `${destination}.${process.pid}.${Date.now()}.tmp`;
    await writeFile(temporary, bytes); await rename(temporary, destination);
  }

  async #remember(semantic, record) {
    await mkdir(this.cacheDirectory, {recursive:true});
    const path = join(this.cacheDirectory, 'last-known-good.json');
    let index = {};
    try { index = JSON.parse(await readFile(path, 'utf8')); } catch {}
    index[semantic.cache_key] = record;
    await atomicJSON(path, index);
  }

  async #lastKnownGood(semantic, manifest) {
    let record;
    try { record = JSON.parse(await readFile(join(this.cacheDirectory, 'last-known-good.json'), 'utf8'))[semantic.cache_key]; } catch { return null; }
    const current = manifest.rows.find(row => clean(row.asset_id) === record?.asset_id && isEligible(row, semantic));
    if (!current || clean(current.version || '1') !== clean(record.version || '1')) return null;
    try { if (!(await stat(record.path)).isFile()) return null; } catch { return null; }
    const token = digest(`${record.asset_id}\0${record.version}\0${record.revision}`).slice(0, 32);
    this.issued.set(token, {...record, etag:record.content_hash || record.revision});
    return descriptor(current, manifest, token, record.revision, 'last_known_good', this.publicPrefix);
  }
}

function normalizeSemanticRequest(request = {}) {
  const audience = key(request.audience || 'SHARED_SCREEN');
  const subjectType = key(request.subject_type);
  const subjectID = canonicalSubjectID(subjectType, request.subject_id);
  const assetRole = canonicalAssetRole(request.asset_role || request.role);
  return {
    subject_id:subjectID, subject_type:subjectType,
    asset_role:assetRole, scene_context_id:key(request.scene_context_id),
    audience, knowledge_scope:key(request.knowledge_scope || 'PUBLIC'),
    fallback:clean(request.fallback) || 'neutral_luminous_ledger',
    cache_key:digest([subjectID, subjectType, assetRole,
      request.scene_context_id, audience, request.knowledge_scope || 'PUBLIC'].map(key).join('|')).slice(0, 24),
  };
}

function isEligible(asset, request) {
  const status = key(asset.status); const relationship = key(asset.canon_relationship);
  if (!['APPROVED','APPROVED_CURRENT'].includes(status)) return false;
  const presentationReference = relationship === 'PRESENTATION_REFERENCE_ONLY'
    && key(asset.subject_type) === 'ITEM'
    && canonicalAssetRole(asset.asset_role) === 'ITEM_EQUIPMENT_ART'
    && (!request.subject_type || request.subject_type === 'ITEM')
    && (!request.asset_role || request.asset_role === 'ITEM_EQUIPMENT_ART');
  if (relationship && !['CURRENT','APPROVED_CURRENT','CANON_CURRENT','DEPICTS_APPROVED_CANON','PARTIAL_CANON'].includes(relationship)
      && !presentationReference) return false;
  if (!clean(asset.asset_id) || !clean(asset.storage_file_id_or_key || asset.storage_url || asset.source_reference)) return false;
  if (request.subject_id && canonicalSubjectID(asset.subject_type, asset.subject_id) !== request.subject_id) return false;
  if (request.subject_type && key(asset.subject_type) !== request.subject_type) return false;
  if (request.asset_role && canonicalAssetRole(asset.asset_role) !== request.asset_role) return false;
  if (request.scene_context_id && key(asset.scene_context_id) && key(asset.scene_context_id) !== request.scene_context_id) return false;
  const visibility = key(asset.visibility || 'PUBLIC');
  if (request.audience !== 'DM' && ['PRIVATE','DM_ONLY','HOST_ONLY'].includes(visibility)) return false;
  const allowedAudiences = split(asset.provisional_audience);
  if (allowedAudiences.length && !allowedAudiences.includes(request.audience)) return false;
  const scope = key(asset.knowledge_scope || 'PUBLIC');
  if (request.audience !== 'DM' && ['SECRET','HOST','DM_ONLY','UNDISCOVERED'].includes(scope)) return false;
  return true;
}

function compareAssets(left, right) {
  return Number(key(right.is_default) === 'TRUE') - Number(key(left.is_default) === 'TRUE')
    || Number(right.version || 0) - Number(left.version || 0)
    || clean(right.approved_at).localeCompare(clean(left.approved_at));
}

function storageURL(asset, accessToken = process.env.WAYFOLIO_DRIVE_ACCESS_TOKEN || '') {
  const fileID = clean(asset.storage_file_id_or_key);
  if (fileID) return accessToken
    ? `https://www.googleapis.com/drive/v3/files/${encodeURIComponent(fileID)}?alt=media`
    : `https://drive.google.com/uc?export=download&id=${encodeURIComponent(fileID)}`;
  const url = clean(asset.storage_url || asset.source_reference);
  return /^https:\/\//i.test(url) ? url : '';
}

function extensionFor(mimeType, source) {
  const mapping = {'image/png':'.png','image/jpeg':'.jpg','image/webp':'.webp','image/gif':'.gif','video/mp4':'.mp4','audio/mpeg':'.mp3','audio/mp4':'.m4a','audio/wav':'.wav'};
  if (mapping[clean(mimeType).split(';')[0]]) return mapping[clean(mimeType).split(';')[0]];
  try { return /\.[a-z0-9]{2,5}$/i.exec(new URL(clean(source)).pathname)?.[0] || '.bin'; }
  catch { return '.bin'; }
}

function mimeFromExtension(extension) {
  return ({'.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.webp':'image/webp','.gif':'image/gif','.mp4':'video/mp4','.mp3':'audio/mpeg','.m4a':'audio/mp4','.wav':'audio/wav'})[extension] || 'application/octet-stream';
}

function descriptor(asset, manifest, token, revision, source, prefix) {
  return {state:'ready', asset_id:clean(asset.asset_id), display_name:clean(asset.display_name),
    subject_type:clean(asset.subject_type), subject_id:clean(asset.subject_id), asset_role:clean(asset.asset_role),
    version:clean(asset.version) || '1', revision, mime_type:clean(asset.mime_type), content_hash:clean(asset.content_hash),
    url:`${prefix}/${token}`, source, manifest_authority:manifest.authority, manifest_revision:manifest.revision};
}

async function atomicJSON(path, value) {
  await mkdir(resolve(path, '..'), {recursive:true});
  const temporary = `${path}.${process.pid}.${Date.now()}.tmp`;
  await writeFile(temporary, `${JSON.stringify(value, null, 2)}\n`); await rename(temporary, path);
}

export const assetResolverInternals = {parseCSV, rowsToRecords, isEligible, normalizeSemanticRequest, storageURL, canonicalSubjectID, canonicalAssetRole};
