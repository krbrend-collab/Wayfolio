import assert from 'node:assert/strict';
import {absentCharacterActions, reconcileJourneyProjection} from './journey-continuity.mjs';

const lifecycle = {
  renn:{party_membership:'active', reveal_state:'introduced', scene_presence:'present'},
  soren:{party_membership:'active', reveal_state:'introduced', scene_presence:'absent'},
  lupin:{party_membership:'active', reveal_state:'introduced', scene_presence:'absent'},
};
const tutorial = {
  location:{id:'location_creature_care_center', name:'Hemlock Creature Care Center'},
  party:[{id:'renn', name:'Renn Hazel', present:true}, {id:'soren', name:'Soren Hazel', present:false}, {id:'lupin', name:'Lupin', present:false}],
  active_entities:[{id:'unbound-rowan-reference', kind:'unbound_npc_reference'}, {id:'injured-slime', kind:'injured_creature', location_id:'pine-root-path'}],
  known_clues:['The slime is injured.'], open_pressures:['Seek help for the injured slime.'],
};
const contaminated = {
  ...structuredClone(tutorial),
  party:[{id:'renn', name:'Renn Hazel', present:true}, {id:'soren', name:'Soren Hazel', present:true}, {id:'lupin', name:'Lupin', present:true}],
  active_entities:[{id:'bridge-motes'}, {id:'crown-hare'}],
  known_clues:['The motes do not merely drift against the wind; they can gather into a coherent luminous trail beneath the bridge rail.'],
  open_pressures:['The Crown Hare may reveal or conceal the route beneath the bridge.'],
};

const repaired = reconcileJourneyProjection({journeyID:'renn-intro-tutorial', worldState:contaminated,
  characterLifecycle:lifecycle, tutorialWorldState:tutorial});
assert.deepEqual(repaired.worldState.party.filter(member => member.present).map(member => member.id), ['renn']);
assert.equal(repaired.worldState.active_entities.some(entity => ['bridge-motes','crown-hare'].includes(entity.id)), false);
assert.equal(repaired.worldState.active_entities.some(entity => entity.id === 'unbound-rowan-reference'), true);
assert.equal(repaired.worldState.known_clues.includes('The slime is injured.'), true);
assert.equal(repaired.corrections.length > 0, true);

assert.deepEqual(absentCharacterActions({public_narration:'Rowan answers carefully.', companion_lines:[
  {speaker_id:'unbound-rowan-reference',text:'I can help.'},
]}, repaired.worldState, [{id:'renn',name:'Renn Hazel'}]), []);

const violations = absentCharacterActions({public_narration:'Soren walks over to the treatment bench.',
  companion_lines:[{speaker_id:'lupin', text:'Ready.', performance:'calm'}]}, repaired.worldState,
[{id:'renn',name:'Renn Hazel'}, {id:'soren',name:'Soren Hazel'}, {id:'lupin',name:'Lupin'}]);
assert.equal(violations.length, 2);
assert.deepEqual(absentCharacterActions({public_narration:'Soren is not currently here.', companion_lines:[]}, repaired.worldState,
  [{id:'soren',name:'Soren Hazel'}]), []);

console.log('Journey projection isolation and absent-character continuity guard passed.');
