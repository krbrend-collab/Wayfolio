import assert from 'node:assert/strict';
import {canReceiveKnowledge, eligibleAffordances, eligibleNarrativeMoments,
  reactionDisposition, updateReactionPolicy} from './gameplay-policy.mjs';
import {filterKnowledgeRecordsForViewer, upsertKnowledgeRecord} from './knowledge-records.mjs';

const state = {};
assert.deepEqual(reactionDisposition(state, 'opportunity_attack'), {mode:'ASK', outcome:'PLAYER_DECISION_REQUIRED'});
assert.throws(() => updateReactionPolicy(state, {behavior_class:'opportunity_attack', mode:'AUTOMATIC'}), /explicit authorization/i);
updateReactionPolicy(state, {behavior_class:'opportunity_attack', mode:'AUTOMATIC', explicit_authorization:true});
assert.equal(reactionDisposition(state, 'opportunity_attack').outcome, 'AUTHORITATIVE_RESOLUTION_ALLOWED');
updateReactionPolicy(state, {behavior_class:'counterspell', mode:'OFF'});
assert.equal(reactionDisposition(state, 'counterspell').outcome, 'DISABLED');

const renn = {role:'wayfolio', character_id:'renn'};
const yugen = {role:'wayfolio', character_id:'yugen'};
const screen = {role:'screen'};
assert.equal(canReceiveKnowledge({knowledge_scope:'PRIVATE', owner_character_id:'renn'}, renn), true);
assert.equal(canReceiveKnowledge({knowledge_scope:'PRIVATE', owner_character_id:'renn'}, yugen), false);
assert.equal(canReceiveKnowledge({knowledge_scope:'CHARACTER', owner_character_id:'renn'}, screen), false);
assert.equal(canReceiveKnowledge({knowledge_scope:'PARTY'}, screen), true);
assert.equal(canReceiveKnowledge({knowledge_scope:'PUBLIC WORLD'}, screen), true);

let records = [];
records = upsertKnowledgeRecord(records, {id:'private-renn', name:'Private clue', knowledge_scope:'PRIVATE', owner_character_id:'renn'}).records;
records = upsertKnowledgeRecord(records, {id:'party-clue', name:'Party clue', knowledge_scope:'PARTY', relevance:20}).records;
assert.deepEqual(filterKnowledgeRecordsForViewer(records, yugen).map(value => value.id), ['party-clue']);

const moments = eligibleNarrativeMoments([
  {id:'eligible', requirements:['bridge-open'], priority:10, knowledge_scope:'PARTY', presentation:'A bell answers.'},
  {id:'secret', requirements:['bridge-open'], priority:20, knowledge_scope:'PRIVATE', owner_character_id:'renn', presentation:'Renn hears a name.'},
  {id:'expired', requirements:[], priority:99, expires_at:'2020-01-01T00:00:00Z', presentation:'Too late.'},
], {satisfied_requirements:['bridge-open'], participant_ids:[]}, yugen, new Date('2026-09-10T00:00:00Z'));
assert.deepEqual(moments.map(value => value.id), ['eligible']);

const affordances = eligibleAffordances([
  {id:'workbench', kind:'work_surface', label:'Herbal workbench', relevance:10, knowledge_scope:'PARTY'},
  {id:'hidden-latch', kind:'interactable', relevance:99, perceived:false, knowledge_scope:'PARTY'},
], yugen);
assert.deepEqual(affordances.map(value => value.id), ['workbench']);

console.log('ASK/AUTOMATIC/OFF, knowledge scopes, narrative moments, and contextual affordance policies passed.');
