import assert from 'node:assert/strict';
import {acquireStorytellerGenerationLease, buildStorytellerContext, buildStorytellerResumeContext,
  commitStorytellerTurn, completeStorytellerGenerationLease, createStorytellerState,
  failStorytellerGenerationLease, filterStorytellerTurnForViewer, rolloverStorytellerThread,
  STORYTELLER_PROTOCOL_VERSION} from './storyteller-runtime.mjs';

const baseLease = {actorId:'renn', turnId:'turn:renn:1', idempotencyKey:'turn:renn:1:final',
  ownerId:'host-a', now:1_000, leaseDurationMs:30_000,
  visibility:{scope:'CHARACTER_IDS',characterIds:['renn']},
  pendingInteraction:{exact_declaration:'I quietly examine the moss without touching it.'}};

// F42: a generation boundary survives the same serialization used by autosave.
let acquired = acquireStorytellerGenerationLease(createStorytellerState(), baseLease);
let state = createStorytellerState(JSON.parse(JSON.stringify(acquired.state)));
assert.equal(state.generationLeases[baseLease.idempotencyKey].status, 'ACTIVE');
assert.equal(state.generationLeases[baseLease.idempotencyKey].pendingInteraction.exact_declaration,
  baseLease.pendingInteraction.exact_declaration);

// F43: a duplicate in the same live host does not create a second lease.
const held = acquireStorytellerGenerationLease(state, {...baseLease, now:2_000});
assert.equal(held.status, 'HELD');
assert.equal(held.lease.attempt, 1);

// F44: a restarted host can safely take over the unresolved idempotent request.
const recovered = acquireStorytellerGenerationLease(state, {...baseLease, ownerId:'host-b', now:3_000});
assert.equal(recovered.status, 'ACQUIRED');
assert.equal(recovered.recovered, true);
assert.equal(recovered.lease.attempt, 2);
state = recovered.state;

// F45: a provider/thread rollover preserves the unresolved player declaration.
const rolled = rolloverStorytellerThread(state, {actorId:'renn',toThreadId:'thread:renn:replacement',now:4_000,
  reason:'provider thread unavailable'});
assert.equal(rolled.state.generationLeases[baseLease.idempotencyKey].status, 'RECOVERABLE');
assert.equal(rolled.state.generationLeases[baseLease.idempotencyKey].pendingInteraction.exact_declaration,
  baseLease.pendingInteraction.exact_declaration);

// F46: recovery is rebuilt from canonical state; no old provider transcript is required or emitted.
const resume = buildStorytellerResumeContext(rolled.state, {sessionId:'HEMLOCK',actorId:'renn',
  campaignSnapshot:{state_head:'abc',location:{id:'hemlock-bridge'},known_clues:['Moss remembers rain.']}});
assert.equal(resume.pendingInteraction.input.exact_declaration, baseLease.pendingInteraction.exact_declaration);
assert.equal(JSON.stringify(resume).includes('transcript'), false);
assert.equal(resume.campaignSnapshot.state_head, 'abc');

// F47: player lifecycles are independent.
const yugen = acquireStorytellerGenerationLease(rolled.state, {actorId:'yugen',turnId:'turn:yugen:1',
  idempotencyKey:'turn:yugen:1:final',ownerId:'host-b',now:5_000,
  visibility:{scope:'PARTY'},pendingInteraction:{exact_declaration:'I raise the lantern.'}});
assert.equal(yugen.state.threadLifecycles.renn.threadId, 'thread:renn:replacement');
assert.notEqual(yugen.state.threadLifecycles.yugen.threadId, yugen.state.threadLifecycles.renn.threadId);

// F48: rollover never widens private presentation visibility.
const privateTurn = {protocolVersion:STORYTELLER_PROTOCOL_VERSION,sessionId:'HEMLOCK',turnId:'turn:renn:1',
  basedOnStateVersion:0,responseMode:'FINAL',resolutionRequests:[],proposedGameEvents:[],knowledgeGrants:[],
  canonProposals:[],continuityUpdates:[],nextInput:{awaitingInput:true},narrativeSegments:[
    {visibility:{scope:'PARTY'},speakerId:'narrator',text:'The bridge remains quiet.'},
    {visibility:{scope:'CHARACTER_IDS',characterIds:['renn']},speakerId:'narrator',text:'Only Renn notices the hidden mark.'},
  ]};
assert.equal(filterStorytellerTurnForViewer(privateTurn,{role:'screen'}).narrativeSegments.length,1);
assert.equal(filterStorytellerTurnForViewer(privateTurn,{role:'wayfolio',characterId:'renn'}).narrativeSegments.length,2);

// F49: completed generation and canonical commit both replay without duplication.
const reacquired = acquireStorytellerGenerationLease(yugen.state, {...baseLease,ownerId:'host-c',now:6_000});
const completed = completeStorytellerGenerationLease(reacquired.state, {idempotencyKey:baseLease.idempotencyKey,
  ownerId:'host-c',now:7_000,result:{value:{public_narration:'The moss stirs once.'},provider_response_id:'resp-1'}});
const generationReplay = acquireStorytellerGenerationLease(completed.state, {...baseLease,ownerId:'host-d',now:8_000});
assert.equal(generationReplay.status,'REPLAY');
assert.equal(generationReplay.result.provider_response_id,'resp-1');

const context = buildStorytellerContext({sessionId:'HEMLOCK',turnId:'turn:commit:1',stateVersion:0,
  sceneId:'bridge',trigger:'player_action',causationId:'action:1',playerInput:{actorCharacterId:'renn',rawIntent:'I listen.'},
  canon:{},scene:{},mechanics:{},knowledge:{},capabilities:{}});
const finalTurn = {protocolVersion:STORYTELLER_PROTOCOL_VERSION,sessionId:'HEMLOCK',turnId:'turn:commit:1',
  basedOnStateVersion:0,responseMode:'FINAL',narrativeSegments:[{visibility:{scope:'PARTY'},text:'Water answers.'}],
  resolutionRequests:[],proposedGameEvents:[],knowledgeGrants:[],canonProposals:[],continuityUpdates:[],nextInput:{awaitingInput:true}};
const firstCommit = commitStorytellerTurn(createStorytellerState(),context,finalTurn,{canonicalEventIds:['event:1']});
const replayCommit = commitStorytellerTurn(firstCommit.state,context,finalTurn,{canonicalEventIds:['event:2']});
assert.equal(replayCommit.status,'REPLAY');
assert.deepEqual(replayCommit.receipt.canonicalEventIds,['event:1']);

const failed = failStorytellerGenerationLease(yugen.state,{idempotencyKey:'turn:yugen:1:final',ownerId:'host-b',error:'network lost'});
assert.equal(failed.lease.status,'RECOVERABLE');
console.log('F42-F49 storyteller continuity, recovery, isolation, visibility, and idempotency tests passed.');
