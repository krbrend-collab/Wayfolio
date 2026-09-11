import assert from 'node:assert/strict';
import {interpretDeclaration, validateInterpretation} from './gameplay-interpreter.mjs';

const actor = {id:'renn', name:'Renn Hazel', default_skill:'Insight'};
const party = [
  {id:'soren', name:'Soren', capabilities:['herbalism'], can_receive_items:true},
  {id:'lupin', name:'Lupin', capabilities:['tracking'], can_receive_items:true},
];
const base = {present_entities:party, inventory:[{id:'healing-potion',name:'Potion of Healing',kind:'potion'}]};

function run(id, declaration, state, expected, visibility = 'public') {
  const value = interpretDeclaration({declaration, actor, state:{...base,...state}, visibility});
  assert.equal(value.exact_declaration, declaration, `${id}: declaration changed`);
  assert.equal(validateInterpretation(value).valid, true, `${id}: invalid schema`);
  for (const [path, wanted] of Object.entries(expected)) {
    const actual = path.split('.').reduce((cursor, key) => cursor?.[key], value);
    assert.deepEqual(actual, wanted, `${id}: ${path}`);
  }
  return value;
}

run('WI-001','I walk over to Soren and stand beside her.',{}, {'resolution.kind':'automatic','clarification_required':false});
run('WI-002','I look at the blue motes beneath the rail. What can I plainly see?',{plainly_visible:true},{'resolution.kind':'information'});
run('WI-003','From my herbalist training, do I recognize whether this pollen is commonly medicinal?',{actor_known_information:true},{'resolution.kind':'information'});
run('WI-004','I test the old bridge latch to see whether I can open it without snapping the corroded mechanism.',{}, {'resolution.kind':'check','resolution.target_kind':'dc'});
run('WI-005','I keep my footing as the bridge lurches beneath me.',{involuntary_threat:true,save_ability:'Dexterity',save_dc:13},{'resolution.kind':'saving_throw','resolution.ability':'Dexterity','resolution.dc':13});
run('WI-006','I follow the glowing trail using the map marks I made here yesterday.',{established_map_marks:true},{'resolution.advantage_state':'advantage'});
run('WI-007','I try to read the tiny inscription through the smoke without moving closer.',{heavy_smoke:true},{'resolution.advantage_state':'disadvantage'});
const cancelled = run('WI-008',"I track the hound by Lupin's fresh trail markers despite the driving rain.",{valid_trail_markers:true,driving_rain:true},{'resolution.advantage_state':'normal'});
assert.equal(cancelled.resolution.advantage_sources.length,1); assert.equal(cancelled.resolution.disadvantage_sources.length,1);
run('WI-009','I examine the crushed herbs while Soren compares them with her field notes.',{}, {'resolution.advantage_state':'advantage'});
run('WI-010','Lupin helps me decipher the sealed archmage notation.',{}, {'resolution.kind':'impossible'});
run('WI-011','I race Lupin to the fern line.',{contest_accepted:true},{'resolution.kind':'opposed_check','resolution.target_actor_id':'lupin'});
run('WI-012','I try to convince the wary gatekeeper that our marked invitation is authentic.',{}, {'resolution.kind':'check','resolution.target_kind':'dc'});
run('WI-013','I hold still and watch the Crown Hare.',{plainly_visible:true,hostile_action_active:false},{'resolution.kind':'information'});
run('WI-014','I dive for the falling lantern before the Gloam Hound can knock it into the dry roots.',{moment_by_moment_order_matters:true},{'resolution.kind':'initiative'});
run('WI-015','I lift the entire stone bridge with one hand.',{}, {'resolution.kind':'impossible'});
const targetClarification = run('WI-016','I give them the potion.',{}, {'resolution.kind':'clarification','clarification_required':true});
assert.match(targetClarification.clarification_question,/Soren or Lupin/);
run('WI-017','I ask Soren whether she recognizes the motes.',{}, {'resolution.kind':'automatic','clarification_required':false});
run('WI-018','Are you okay?',{}, {'resolution.kind':'automatic','clarification_required':false});
run('WI-019','What happened here?',{}, {'resolution.kind':'automatic','clarification_required':false});
run('WI-020','I nod and thank Rowan.',{}, {'resolution.kind':'automatic','clarification_required':false});
run('WI-021','That does not sound like the Rowan I remember.',{}, {'resolution.kind':'automatic','clarification_required':false});
run('WI-022',"I don’t have the slime with me. He’s still in the forest. I didn’t want to move him with the metal still inside him because I didn’t know what would happen.",{}, {'resolution.kind':'automatic','clarification_required':false});
run('WI-023','What do we need to take with?',{}, {'resolution.kind':'automatic','clarification_required':false});
run('WI-024','Master Rowan, can you help it? How does something get stuck in a slime anyway?',{}, {'resolution.kind':'automatic','clarification_required':false});
run('WI-025','Are you going to come with me there?',{}, {'resolution.kind':'automatic','clarification_required':false});

const potionClarification = run('WI-026','I drink the potion.',{inventory:[
  {id:'healing-potion',name:'Potion of Healing',kind:'potion'}, {id:'night-sight',name:'Potion of Night Sight',kind:'potion'}]},
  {'resolution.kind':'clarification','clarification_required':true});
assert.match(potionClarification.clarification_question,/Potion of Healing or Potion of Night Sight/);

run('WI-027','I inspect the blue motes for a pattern without touching them.',{},
  {'resolution.kind':'automatic','clarification_required':false});
run('WI-028','I study the supplies Rowan placed on the table.',{present_entities:[...party,
  {id:'rowan',name:'Rowan',capabilities:[],can_receive_items:true}]},
  {'resolution.kind':'automatic','clarification_required':false,'target_refs':['rowan']});
run('WI-029','I investigate the stones for a concealed mechanism.',{},
  {'resolution.kind':'check','clarification_required':false});
run('WI-030','I try to read the tiny inscription through the smoke.',{heavy_smoke:true},
  {'resolution.kind':'check','resolution.advantage_state':'disadvantage'});
run('WI-031','I race Rowan to the service door.',{contest_accepted:true,
  present_entities:[...party,{id:'unbound-rowan-reference',name:'Rowan',capabilities:[],can_receive_items:true}]},
  {'resolution.kind':'opposed_check','resolution.target_actor_id':'unbound-rowan-reference'});

console.log('Tier A interpreter fixtures passed: WI-001 through WI-031.');
