import assert from 'node:assert/strict';
import {buildResolutionPacket, buildStorytellerContext, canViewVisibility, commitStorytellerTurn,
  createStorytellerState, filterStorytellerTurnForViewer, prepareStorytellerTurn,
  STORYTELLER_PROTOCOL_VERSION} from './storyteller-runtime.mjs';
import {StorytellerAdapter} from './storyteller-adapter.mjs';

const context = buildStorytellerContext({sessionId:'HEMLOCK', turnId:'turn:test:1', stateVersion:0,
  sceneId:'scene:bridge', trigger:'player_action', causationId:'action:1',
  playerInput:{actorPlayerId:'player:renn', actorCharacterId:'renn', source:'iphone', rawIntent:'I inspect the blue motes without touching them.'},
  canon:{locked:['Renn is a Harengon healer.'], established:[], gmOnly:['The motes answer the Crown Hare.'],
    unresolvedThreads:['What lies beneath the bridge?'], continuitySummary:[], constraints:['Never choose Renn’s actions.']},
  scene:{locationId:'hemlock-bridge', sceneId:'scene:bridge', presentCharacterIds:['renn','soren','lupin'], mode:'exploration'},
  mechanics:{characters:{renn:{skills:{Nature:3}}}}, knowledge:{renn:{known:['blue motes are visible']}},
  capabilities:{automatedRolls:true, physicalDice:true, privateWayfolios:true}});

let state = createStorytellerState();
const needsRoll = {protocolVersion:STORYTELLER_PROTOCOL_VERSION, sessionId:'HEMLOCK', turnId:'turn:test:1',
  basedOnStateVersion:0, responseMode:'NEEDS_RESOLUTION',
  narrativeSegments:[{visibility:{scope:'PARTY'},speakerId:'narrator',text:'The motes tighten into a delicate spiral.',dependsOnResolutionIds:[]}],
  resolutionRequests:[{resolutionId:'nature:1',type:'ability_check',actorId:'renn',mechanic:{skill:'Nature'},
    challenge:{dc:12},visibility:{scope:'PARTY'},reason:'The pattern is subtle enough to require trained attention.'}],
  proposedGameEvents:[],knowledgeGrants:[],canonProposals:[],continuityUpdates:[],nextInput:{awaitingInput:false}};
const prepared = prepareStorytellerTurn(state, context, needsRoll);
assert.equal(prepared.status, 'NEEDS_RESOLUTION'); state = prepared.state;
const resolution = buildResolutionPacket(state, {turnId:'turn:test:1',stateVersion:0,
  results:[{resolutionId:'nature:1',die:16,modifier:3,total:19,dc:12,succeeded:true}]});
assert.equal(resolution.results[0].total, 19);

const finalTurn = {...needsRoll,responseMode:'FINAL',resolutionRequests:[], narrativeSegments:[
  {visibility:{scope:'PARTY'},speakerId:'narrator',text:'The spiral resolves into a trail beneath the bridge.'},
  {visibility:{scope:'CHARACTER_IDS',characterIds:['renn']},speakerId:'narrator',text:'Renn recognizes the pattern as deliberate guidance.'},
  {visibility:{scope:'GM_ONLY'},speakerId:'narrator',text:'The Crown Hare is testing Renn.'}],
  proposedGameEvents:[{proposalId:'event:1',eventType:'map.locationDiscovered',entityRefs:['hemlock-bridge'],
    payload:{locationId:'bridge-underway'},persistence:'persistent',visibility:{scope:'PARTY'},cause:'turn:test:1'}],
  knowledgeGrants:[{knowledgeGrantId:'knowledge:1',recipientCharacterIds:['renn'],entityRef:'bridge-underway',
    operation:'create-entry',content:{name:'Bridge Underway'},source:'observation',manifestation:true}],
  canonProposals:[{temporaryId:'temp:npc:1',entityType:'npc',publicFacts:{name:'The Lantern Keeper'},
    gmOnlyFacts:{motive:'Protect the rootway'},persistenceRecommendation:'persistent'}],
  continuityUpdates:[{kind:'thread',summary:'Renn found a path beneath the bridge.'}],
  nextInput:{awaitingInput:true,expectedActorIds:['renn'],inputType:'free-action'}};
const committed = commitStorytellerTurn(state, context, finalTurn, {stableIdMappings:{'temp:npc:1':'npc:lantern-keeper'},canonicalEventIds:['event:canonical:1']});
assert.equal(committed.status, 'COMMITTED'); assert.equal(committed.receipt.newStateVersion, 1);
assert.equal(committed.receipt.stableIdMappings['temp:npc:1'], 'npc:lantern-keeper');
state = committed.state;
const replay = commitStorytellerTurn(state, context, finalTurn, {});
assert.equal(replay.status, 'REPLAY'); assert.equal(replay.receipt.newStateVersion, 1);
const stale = prepareStorytellerTurn(state, {...context,turnId:'turn:test:2',causationId:'action:2',stateVersion:0},
  {...finalTurn,turnId:'turn:test:2',basedOnStateVersion:0});
assert.equal(stale.status, 'STALE_STATE'); assert.equal(stale.repairRequired, true);

const playerView = filterStorytellerTurnForViewer(finalTurn,{role:'wayfolio',playerId:'player:renn',characterId:'renn'});
assert.equal(playerView.narrativeSegments.length,2); assert.deepEqual(playerView.canonProposals[0].gmOnlyFacts,{});
const otherView = filterStorytellerTurnForViewer(finalTurn,{role:'wayfolio',playerId:'player:soren',characterId:'soren'});
assert.equal(otherView.narrativeSegments.length,1);
assert.equal(canViewVisibility({scope:'GM_ONLY'},{role:'screen'}),false);
assert.equal(canViewVisibility({scope:'GM_ONLY'},{role:'dm'}),true);

let providerPhase = 'begin';
const adapter = new StorytellerAdapter({generate:async ({messageType}) => {
  if (messageType === 'StorytellerContext') { providerPhase = 'resolution'; return needsRoll; }
  if (messageType === 'ResolutionPacket') { providerPhase = 'final'; return finalTurn; }
  throw new Error('Unexpected provider phase.');
}});
let adapterState = createStorytellerState();
const adapterBeginning = await adapter.begin({state:adapterState,context});
assert.equal(adapterBeginning.status,'NEEDS_RESOLUTION'); adapterState = adapterBeginning.state;
const adapterFinal = await adapter.complete({state:adapterState,context,
  resolutionResults:[{resolutionId:'nature:1',die:16,modifier:3,total:19,dc:12,succeeded:true}]});
assert.equal(adapterFinal.status,'FINAL'); assert.equal(providerPhase,'final');
console.log('Storyteller context, two-phase resolution, commit receipts, idempotency, stale-state repair, stable IDs, and visibility filtering passed.');
