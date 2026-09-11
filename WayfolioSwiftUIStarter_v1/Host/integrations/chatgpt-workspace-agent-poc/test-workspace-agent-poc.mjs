import assert from 'node:assert/strict';
import {buildStorytellerContext, STORYTELLER_PROTOCOL_VERSION} from '../../storyteller-runtime.mjs';
import {WorkspaceAgentStoryteller} from './workspace-agent-storyteller.mjs';
import {WayfolioMCPToolBridge} from './wayfolio-mcp-tools.mjs';

const requests = [];
const jsonResponse = (status, body) => new Response(JSON.stringify(body), {status, headers:{'content-type':'application/json'}});
const fetchImpl = async (url, options = {}) => {
  requests.push({url, options});
  if (url.endsWith('/trigger')) return jsonResponse(202, {conversation_url:'https://chatgpt.com/c/poc', agent_trigger_run_id:'apirun_poc'});
  if (url.endsWith('/runs/apirun_poc')) return jsonResponse(200, {id:'apirun_poc', status:'completed', conversation_url:'https://chatgpt.com/c/poc', error:null});
  return jsonResponse(404, {});
};

const storyteller = new WorkspaceAgentStoryteller({accessToken:'wa-token', agentTriggerId:'agtch_poc', fetchImpl});
const triggered = await storyteller.triggerTurn({
  turnId:'turn-1', conversationKey:'campaign-hemlock', idempotencyKey:'event-1',
  input:JSON.stringify({turn_id:'turn-1', instruction:'Read Wayfolio context, resolve naturally, and publish exactly once.'}),
});
assert.equal(triggered.accepted, true);
assert.equal(triggered.runId, 'apirun_poc');
assert.equal(requests[0].options.headers['Idempotency-Key'], 'event-1');
assert.equal(JSON.parse(requests[0].options.body).conversation_key, 'campaign-hemlock');
assert.deepEqual(await storyteller.getRunStatus('apirun_poc'), {
  runId:'apirun_poc', status:'completed', terminal:true, conversationURL:'https://chatgpt.com/c/poc', error:null,
});

let stateRevision = 7;
let proposalsValidated = 0;
const bridge = new WayfolioMCPToolBridge({
  getCurrentStateRevision:() => stateRevision,
  onValidatedTurn:async ({turn}) => {
    proposalsValidated += 1;
    assert.equal(turn.proposedGameEvents.length, 1);
    return {status:'VALIDATED_NOT_COMMITTED'};
  },
});
const context = buildStorytellerContext({
  sessionId:'HEMLOCK', turnId:'turn-1', stateVersion:7, sceneId:'bridge', trigger:'player_action', causationId:'action-1',
  playerInput:{actorCharacterId:'renn', rawIntent:'I quietly ask Soren whether she recognizes the motes.'},
  canon:{continuitySummary:['Renn, Soren, and Lupin reached Hemlock Bridge.']}, scene:{companions:['soren', 'lupin']},
  mechanics:{}, knowledge:{}, capabilities:{privateDeliveries:true},
});
bridge.registerTurn(context);
assert.equal((await bridge.callTool('wayfolio_get_turn_context', {turn_id:'turn-1'})).authoritative, true);

const turn = {
  protocolVersion:STORYTELLER_PROTOCOL_VERSION, sessionId:'HEMLOCK', turnId:'turn-1', basedOnStateVersion:7,
  responseMode:'FINAL', resolutionRequests:[], knowledgeGrants:[], canonProposals:[], continuityUpdates:[{summary:'Renn consulted Soren.'}],
  narrativeSegments:[
    {visibility:{scope:'PARTY'}, speakerId:'soren', text:'They move like seeds, but they are listening.'},
    {visibility:{scope:'CHARACTER_IDS', characterIds:['renn']}, speakerId:'narrator', text:'Renn notices one mote matching Soren’s breathing.'},
  ],
  proposedGameEvents:[{eventType:'relationship_observation', payload:{observer:'renn', subject:'soren'}, visibility:{scope:'CHARACTER_IDS', characterIds:['renn']}}],
  nextInput:{awaitingInput:true, expectedActorIds:['renn'], inputType:'free-action'},
};
const published = await bridge.callTool('wayfolio_publish_turn', {turn_id:'turn-1', expected_state_revision:7, storyteller_turn:turn});
assert.equal(published.accepted, true);
assert.equal(published.proposal_status, 'VALIDATED_NOT_COMMITTED');
assert.deepEqual(published.delivery_counts, {publicSegments:1, privateSegments:1});
assert.equal(proposalsValidated, 1);

const replay = await bridge.callTool('wayfolio_publish_turn', {turn_id:'turn-1', expected_state_revision:7, storyteller_turn:turn});
assert.equal(replay.replayed, true);
assert.equal(proposalsValidated, 1, 'A retry must not validate or commit twice.');
await assert.rejects(
  () => bridge.callTool('wayfolio_publish_turn', {turn_id:'turn-1', expected_state_revision:7, storyteller_turn:{...turn, continuityUpdates:[]}}),
  /reused with different content/,
);

const staleContext = buildStorytellerContext({...context, turnId:'turn-stale', causationId:'action-2'});
bridge.registerTurn(staleContext);
stateRevision = 8;
const stale = await bridge.callTool('wayfolio_publish_turn', {
  turn_id:'turn-stale', expected_state_revision:7,
  storyteller_turn:{...turn, turnId:'turn-stale'},
});
assert.equal(stale.accepted, false);
assert.equal(stale.code, 'STALE_STATE');

const failedContext = buildStorytellerContext({...context, turnId:'turn-failed', stateVersion:8, causationId:'action-3'});
bridge.registerTurn(failedContext);
const failure = await bridge.callTool('wayfolio_report_failure', {turn_id:'turn-failed', code:'TOOL_UNAVAILABLE', message:'The return tool could not complete.'});
assert.equal(failure.accepted, true);
assert.ok(bridge.auditLog().some(entry => entry.type === 'TURN_FAILED'));

console.log('Workspace Agent storyteller PoC tests passed.');
