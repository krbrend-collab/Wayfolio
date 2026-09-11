import assert from 'node:assert/strict';
import {StorytellerAdapter} from './storyteller-adapter.mjs';
import {buildStorytellerContext, commitStorytellerTurn, createStorytellerState, STORYTELLER_PROTOCOL_VERSION} from './storyteller-runtime.mjs';
import {OpenAIStorytellerTransport} from './storyteller-transport.mjs';

let calls = 0;
const jsonResponse = (status, body, headers = {}) => new Response(JSON.stringify(body), {status, headers:{'content-type':'application/json', ...headers}});
const mockFetch = async (url, options = {}) => {
  if (url.endsWith('/models')) {
    if (options.headers.Authorization.includes('bad')) return jsonResponse(401, {error:'bad key'});
    return jsonResponse(200, {data:[{id:'gpt-test'}]});
  }
  calls += 1;
  const request = JSON.parse(options.body); const input = JSON.parse(request.input);
  const context = input.context;
  const turn = input.messageType === 'ResolutionPacket'
    ? {protocolVersion:STORYTELLER_PROTOCOL_VERSION, sessionId:context.sessionId, turnId:context.turnId,
      basedOnStateVersion:context.stateVersion, responseMode:'FINAL', resolutionRequests:[], proposedGameEvents:[], knowledgeGrants:[], canonProposals:[], continuityUpdates:[{summary:'Renn discovered the safe crossing.'}],
      narrativeSegments:[{visibility:{scope:'PARTY'},speakerId:'narrator',text:'The motes settle into a safe path.'}], nextInput:{awaitingInput:true,expectedActorIds:['renn'],inputType:'free-action'}}
    : {protocolVersion:STORYTELLER_PROTOCOL_VERSION, sessionId:context.sessionId, turnId:context.turnId,
      basedOnStateVersion:context.stateVersion, responseMode:'NEEDS_RESOLUTION', narrativeSegments:[], proposedGameEvents:[], knowledgeGrants:[], canonProposals:[], continuityUpdates:[],
      resolutionRequests:[{resolutionId:'nature-check',type:'ability_check',actorId:'renn',mechanic:{skill:'Nature'},challenge:{dc:12},visibility:{scope:'PARTY'},reason:'The outcome is uncertain.'}], nextInput:{awaitingInput:false,expectedActorIds:[],inputType:'resolution'}};
  return jsonResponse(200, {id:`resp-${calls}`, output_text:JSON.stringify(turn)}, {'x-request-id':`req-${calls}`});
};

const states = [];
const transport = new OpenAIStorytellerTransport({fetchImpl:mockFetch, model:'gpt-test', softTimeoutMs:50,
  onState:status => states.push(status.state)});
await transport.connect({apiKey:'sk-good-12345678901234567890'});
assert.equal(transport.publicStatus().active, true);
assert.equal('key_hint' in transport.publicStatus(), false, 'Shared status must not expose credential hints.');

await assert.rejects(() => transport.replace({apiKey:'sk-bad-12345678901234567890'}), error => error.code === 'REAUTHORIZATION_REQUIRED');
assert.equal(transport.publicStatus().active, true, 'A failed replacement must retain the valid connection.');

const context = buildStorytellerContext({sessionId:'HEMLOCK',turnId:'turn-1',stateVersion:0,sceneId:'bridge',trigger:'player_action',causationId:'action-1',
  playerInput:{actorCharacterId:'renn',rawIntent:'I study the motes.'},canon:{continuitySummary:[]},scene:{},mechanics:{},knowledge:{},capabilities:{}});
const adapter = new StorytellerAdapter({generate:async ({messageType, context, resolutionPacket}) => {
  const result = await transport.generate({idempotencyKey:`${context.turnId}:${messageType}`,messageType,
    payload:{context,resolutionPacket},instructions:'Return a valid Wayfolio StorytellerTurn.'});
  return JSON.parse(result.value);
}});
let state = createStorytellerState();
const begun = await adapter.begin({state,context});
assert.equal(begun.status, 'NEEDS_RESOLUTION'); state = begun.state;
const completed = await adapter.complete({state,context,resolutionResults:[{resolutionId:'nature-check',die:14,modifier:3,total:17,succeeded:true}]});
assert.equal(completed.status, 'FINAL');
const committed = commitStorytellerTurn(completed.state, context, completed.turn, {canonicalEventIds:['event-1']});
assert.equal(committed.status, 'COMMITTED');
assert.equal(committed.receipt.newStateVersion, 1);

const beforeReplay = calls;
const first = await transport.generate({idempotencyKey:'replay-1',messageType:'StorytellerContext',payload:{context},instructions:'Return a valid Wayfolio StorytellerTurn.'});
const replay = await transport.generate({idempotencyKey:'replay-1',messageType:'StorytellerContext',payload:{context},instructions:'Return a valid Wayfolio StorytellerTurn.'});
assert.equal(calls, beforeReplay + 1); assert.equal(replay.replayed, true); assert.equal(replay.value, first.value);
await assert.rejects(() => transport.generate({idempotencyKey:'replay-1',messageType:'StorytellerContext',payload:{context:{...context,sceneId:'different'}},instructions:'Return a valid Wayfolio StorytellerTurn.'}), error => error.code === 'IDEMPOTENCY_CONFLICT');

transport.pending.set('unfinished-turn', {fingerprint:'test',promise:Promise.resolve()});
assert.throws(() => transport.disconnect(), error => error.code === 'TURN_IN_PROGRESS');
transport.pending.clear();
transport.disconnect();
assert.equal(transport.publicStatus().state, 'DISCONNECTED');
assert.equal(committed.state.continuity.length, 1, 'Disconnect must not alter authoritative campaign continuity.');
await transport.connect({apiKey:'sk-new-12345678901234567890'});
assert.equal((await transport.recover()).state, 'ACTIVE');
assert.ok(states.includes('CONNECTING') && states.includes('GENERATING') && states.includes('ACTIVE'));

console.log('WF-010 storyteller transport tests passed.');
