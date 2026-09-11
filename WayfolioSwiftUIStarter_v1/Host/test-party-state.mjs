import assert from 'node:assert/strict';
import {bindWayfolio, defaultCharacterLifecycle, introducePartyMember, isPublicPartyEligible,
  isWayfolioSelectable, normalizeCharacterLifecycle, releaseWayfolio, spriteDiagnostic} from './party-state.mjs';

const characters = new Map([
  ['renn', {id:'renn', name:'Renn Hazel', visual_identity:{version:2, references:[{approved:true}]}}],
  ['soren', {id:'soren', name:'Soren Hazel', visual_identity:{version:3, references:[]}}],
  ['yugen', {id:'yugen', name:'Yūgen'}],
  ['hinosuke', {id:'hinosuke', name:'Hinosuke', record_kind:'companion', owner_character_id:'yugen'}],
  ['guest', {id:'guest', name:'Guest Hero'}],
]);

const state = normalizeCharacterLifecycle({}, characters);
assert.equal(state.renn.playability, 'available_to_play');
assert.equal(state.soren.playability, 'npc_controlled');
assert.equal(state.yugen.playability, 'available_to_play');
assert.equal(state.yugen.reveal_state, 'pending_introduction');
assert.equal(state.hinosuke.playability, 'npc_controlled');
assert.equal(state.guest.playability, 'provisional_import');
assert.equal(isWayfolioSelectable(state.renn), true);
assert.equal(isWayfolioSelectable(state.yugen), true, 'a private Wayfolio can be assigned before public introduction');
assert.equal(isPublicPartyEligible(state.yugen), false, 'a pending player must not appear on the shared table');
assert.equal(isWayfolioSelectable(state.soren), false);
assert.equal(isWayfolioSelectable(state.guest), false, 'an imported character must remain provisional until DM review');

const pending = {...defaultCharacterLifecycle(characters.get('guest')),
  recruitment_state:'accepted', party_membership:'active', reveal_state:'pending_introduction'};
assert.equal(isPublicPartyEligible(pending), false, 'pending introductions must remain absent from public surfaces');
const introduced = introducePartyMember(pending, '2026-09-01T00:00:00.000Z');
assert.equal(introduced.reveal_state, 'introduced');
assert.equal(isPublicPartyEligible(introduced), true);
assert.throws(() => introducePartyMember(introduced), /already been introduced/);

const bound = bindWayfolio(state.renn, {playerID:'player-1', deviceID:'phone-1'}, '2026-09-01T00:00:00.000Z');
assert.deepEqual(bound.player_assignment, {status:'assigned', player_id:'player-1'});
assert.deepEqual(bound.wayfolio_binding, {status:'bound', device_id:'phone-1'});
assert.deepEqual(releaseWayfolio(bound).wayfolio_binding, {status:'unbound', device_id:null});
assert.throws(() => bindWayfolio(state.soren, {playerID:'player-2', deviceID:'phone-2'}), /not currently available/);

assert.equal(spriteDiagnostic(characters.get('renn')).update_state, 'current');
assert.equal(spriteDiagnostic(characters.get('soren')).update_state, 'approved_assets_missing_locally');
assert.equal(spriteDiagnostic(characters.get('soren')).login_metadata_valid, false);

console.log('WF-049 party/reveal/playability/binding boundary tests passed.');
