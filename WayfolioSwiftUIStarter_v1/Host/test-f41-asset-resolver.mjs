import assert from 'node:assert/strict';
import {mkdtemp, readFile, rm, stat} from 'node:fs/promises';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {HostAssetResolver, assetResolverInternals} from './asset-resolver.mjs';

const png = Buffer.from('89504e470d0a1a0a0000000d49484452', 'hex');
const makeResponse = (body = png, status = 200) => new Response(body, {status, headers:{'content-type':'image/png'}});
const approved = ({id = 'location.synthetic.f41', version = '7', hash = ''} = {}) => ({
  asset_id:id, display_name:'F41 Remote Lantern Road', subject_type:'LOCATION', subject_id:'LANTERN_ROAD',
  scene_context_id:'THE_LANTERN_ROAD', asset_role:'SHARED_IPAD_BACKGROUND', storage_provider:'GOOGLE_DRIVE',
  storage_file_id_or_key:`drive-${id}-${version}`, mime_type:'image/png', content_hash:hash,
  status:'APPROVED', canon_relationship:'CURRENT', visibility:'PUBLIC', knowledge_scope:'PUBLIC',
  version, is_default:'TRUE', approved_at:'2026-09-02T12:00:00Z',
});

const temp = await mkdtemp(join(tmpdir(), 'wayfolio-f41-'));
try {
  let manifest = {authority:'DRIVE_VISUAL_ASSET_MANIFEST', revision:'drive-revision-41a', source:'drive', rows:[
    approved(),
    {...approved({id:'location.unreviewed.local', version:'99'}), status:'IN REVIEW',
      storage_file_id_or_key:'locally-newer-but-forbidden'},
  ]};
  const manifestSource = {snapshot:async () => manifest};
  let downloads = 0;
  const fetchImpl = async url => { downloads += 1; assert.match(String(url), /drive-location\.synthetic\.f41-7/); return makeResponse(); };
  const resolver = new HostAssetResolver({manifestSource, cacheDirectory:temp, fetchImpl});
  const request = {subject_type:'location', subject_id:'lantern road', asset_role:'shared ipad background',
    scene_context_id:'The Lantern Road', audience:'shared_screen', knowledge_scope:'public'};

  const first = await resolver.resolve(request);
  assert.equal(first.state, 'ready');
  assert.equal(first.asset_id, 'location.synthetic.f41', 'an in-review locally newer asset must never substitute');
  assert.equal(first.source, 'drive_download');
  assert.equal(downloads, 1, 'bundle/cache absence must cause a Host download');
  const content = await resolver.content(first.url.split('/').at(-1));
  assert.ok(content);
  assert.deepEqual(await readFile(content.path), png);

  const again = await resolver.resolve(request);
  assert.equal(again.state, 'ready');
  assert.equal(again.source, 'host_cache');
  assert.equal(downloads, 1, 'same stable asset version/revision must be reused');

  const restarted = new HostAssetResolver({manifestSource, cacheDirectory:temp,
    fetchImpl:async () => { throw new Error('Drive offline after restart'); }});
  const afterRestart = await restarted.resolve(request);
  assert.equal(afterRestart.state, 'ready');
  assert.equal(afterRestart.source, 'host_cache', 'Host restart must retain the valid cache');
  assert.ok(await restarted.content(afterRestart.url.split('/').at(-1)));

  manifest = {...manifest, revision:'drive-revision-41b', rows:[approved({version:'8'})]};
  const unavailable = new HostAssetResolver({manifestSource, cacheDirectory:temp,
    fetchImpl:async () => makeResponse(Buffer.from('unavailable'), 503)});
  const invalidated = await unavailable.resolve(request);
  assert.equal(invalidated.state, 'fallback', 'a superseded version must invalidate the former cache');
  assert.equal(invalidated.reason, 'asset_download_failed');
  assert.equal(invalidated.fallback, 'neutral_luminous_ledger');

  const unrelated = await resolver.resolve({...request, subject_id:'GARDEN_SHRINE'});
  assert.equal(unrelated.state, 'fallback', 'unmapped or unapproved families must not be exposed');
  assert.equal(unrelated.reason, 'no_eligible_current_asset');

  const quietShrineRequest = assetResolverInternals.normalizeSemanticRequest({
    subject_type:'LOCATION', subject_id:'location_quiet_shrine', asset_role:'shared ipad background'
  });
  const quietShrineAsset = {
    asset_id:'quiet-shrine-approved', status:'APPROVED', canon_relationship:'CURRENT',
    subject_type:'LOCATION', subject_id:'hemlock.garden_shrine', asset_role:'SHARED_IPAD_BACKGROUND',
    storage_file_id_or_key:'drive-file'
  };
  assert.equal(assetResolverInternals.isEligible(quietShrineAsset, quietShrineRequest), true,
    'the Group 8 Garden Shrine production alias must resolve to canonical Quiet Shrine');
  assert.equal(assetResolverInternals.normalizeSemanticRequest({
    subject_type:'LOCATION', subject_id:'hemlock.quiet_shrine'
  }).subject_id, 'LOCATION_QUIET_SHRINE', 'aliases must preserve the Campaign State identity');

  const registeredGroup8 = {
    asset_id:'asset_location_creature_care_center_main_interior', status:'APPROVED CURRENT',
    canon_relationship:'DEPICTS_APPROVED_CANON', subject_type:'LOCATION',
    subject_id:'location_creature_care_center', scene_context_id:'main_interior',
    asset_role:'SHARED_IPAD_LOCATION_BACKGROUND', storage_file_id_or_key:'drive-group-8',
    visibility:'MIXED_FILTER_REQUIRED', knowledge_scope:'IDENTIFIED'
  };
  const group8Request = assetResolverInternals.normalizeSemanticRequest({
    subject_type:'LOCATION', subject_id:'hemlock.creature_care_center',
    asset_role:'SHARED_IPAD_BACKGROUND', scene_context_id:'main_interior', audience:'shared_screen'
  });
  assert.equal(assetResolverInternals.isEligible(registeredGroup8, group8Request), true,
    'approved Group 8 vocabulary must remain eligible after canonical identity and reveal filtering');

  const protectiveGearRequest = assetResolverInternals.normalizeSemanticRequest({
    subject_type:'ITEM', subject_id:'item_cuirass_l1_common', asset_role:'ITEM_EQUIPMENT_ART',
    audience:'PLAYER', knowledge_scope:'KNOWN_WHEN_ELIGIBLE'
  });
  const protectiveGear = {
    asset_id:'asset_item_cuirass_l1_common', status:'APPROVED CURRENT',
    canon_relationship:'PRESENTATION_REFERENCE_ONLY', subject_type:'ITEM',
    subject_id:'item_cuirass_l1_common', asset_role:'ITEM_EQUIPMENT_ART',
    storage_file_id_or_key:'drive-protective-gear', visibility:'PLAYER_SAFE_WHEN_ELIGIBLE',
    knowledge_scope:'KNOWN_WHEN_ELIGIBLE'
  };
  assert.equal(assetResolverInternals.isEligible(protectiveGear, protectiveGearRequest), true,
    'approved current Protective Gear presentation art must resolve for an eligible player');
  assert.equal(assetResolverInternals.isEligible({...protectiveGear, status:'SUPERSEDED'}, protectiveGearRequest), false,
    'superseded Protective Gear must never resolve');
  assert.equal(assetResolverInternals.isEligible({...protectiveGear, asset_role:'WAYFOLIO_RECORD'}, protectiveGearRequest), false,
    'presentation-reference eligibility must remain scoped to item equipment art');

  console.log('F41 PASS — approved Drive-only assets, including eligible Protective Gear, resolve, cache, invalidate, and fall back without blocking play.');
} finally {
  await rm(temp, {recursive:true, force:true});
}
