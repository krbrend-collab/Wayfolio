import assert from 'node:assert/strict';
import {cp, mkdtemp, rm} from 'node:fs/promises';
import {createServer} from 'node:http';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {WebSocket} from 'ws';

function listen(server) {
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => resolve(server.address().port));
  });
}

function connect(port, role, extra = {}) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(`ws://127.0.0.1:${port}/session`);
    const messages = []; const waiters = [];
    socket.on('message', raw => {
      const message = JSON.parse(raw);
      const index = waiters.findIndex(waiter => waiter.predicate(message));
      if (index >= 0) waiters.splice(index, 1)[0].resolve(message); else messages.push(message);
    });
    const next = (predicate, timeout = 12_000) => {
      const index = messages.findIndex(predicate);
      if (index >= 0) return Promise.resolve(messages.splice(index, 1)[0]);
      return new Promise((resolveNext, rejectNext) => {
        const waiter = {predicate, resolve:resolveNext}; waiters.push(waiter);
        const timer = setTimeout(() => {
          const position = waiters.indexOf(waiter); if (position >= 0) waiters.splice(position, 1);
          rejectNext(new Error(`Timed out waiting for ${role}. Recent: ${messages.slice(-10).map(item => item.type).join(', ')}`));
        }, timeout); timer.unref?.();
      });
    };
    socket.once('error', reject);
    socket.once('open', async () => {
      socket.send(JSON.stringify({type:'join', role, session_code:'HEMLOCK', ...extra}));
      await next(message => message.type === 'joined'); resolve({socket, next, messages});
    });
  });
}

async function startHost({port, data, campaign, providerPort}) {
  const child = spawn(process.execPath, ['server.mjs'], {cwd:new URL('.', import.meta.url), env:{...process.env,
    PORT:String(port), WAYFOLIO_DATA_DIRECTORY:data, WAYFOLIO_CAMPAIGN_PATH:campaign,
    WAYFOLIO_OPENAI_BASE_URL:`http://127.0.0.1:${providerPort}/v1`,
    OPENAI_API_KEY:'sk-two-player-turn-test-12345678901234567890', WAYFOLIO_DEBUG:'1'}, stdio:['ignore','pipe','pipe']});
  child.stderr.on('data', chunk => process.stderr.write(`[two-player host] ${chunk}`));
  await new Promise((resolve, reject) => {
    let output = '';
    const timer = setTimeout(() => reject(new Error(`Host did not start. ${output}`)), 15_000);
    child.stdout.on('data', chunk => { output += chunk; process.stderr.write(`[two-player host] ${chunk}`); if (output.includes('Wayfolio host:')) { clearTimeout(timer); resolve(); } });
    child.stderr.on('data', chunk => { output += chunk; });
    child.once('exit', code => { clearTimeout(timer); reject(new Error(`Host exited ${code}. ${output}`)); });
  });
  return child;
}

async function stopHost(child) {
  child.kill('SIGTERM');
  await new Promise(resolve => child.once('exit', resolve));
}

const temporary = await mkdtemp(join(tmpdir(), 'wayfolio-two-player-turn-'));
const campaign = join(temporary, 'campaign');
const data = join(temporary, 'data');
await cp(new URL('../Campaigns/HemlockDevelopment/', import.meta.url), campaign, {recursive:true});
const providerInputs = [];
const provider = createServer(async (request, response) => {
  if (request.url === '/v1/models') return response.writeHead(200, {'content-type':'application/json'}).end(JSON.stringify({data:[]}));
  if (request.url !== '/v1/responses') return response.writeHead(404).end();
  const chunks = []; for await (const chunk of request) chunks.push(chunk);
  const requestBody = JSON.parse(Buffer.concat(chunks).toString('utf8'));
  const input = JSON.parse(requestBody.input); providerInputs.push(input);
  const isPrivate = input.approved_ruling?.visibility === 'private';
  const result = {
    public_narration:isPrivate ? `LEAK:${input.exact_declaration}` : `Yūgen studies the motes without forcing Renn to act.`,
    private_information:isPrivate ? `Private answer for ${input.actor_id}.` : 'Yūgen recognizes that the motes answer to patient observation.',
    companion_lines:[
      {speaker_id:'soren',text:'I can hold the lantern steady while you look.',performance:'warm and helpful'},
      {speaker_id:'lupin',text:'I will watch the path and leave the choice with you.',performance:'grounded and protective'},
      {speaker_id:'hinosuke',text:'This line must be rejected.',performance:'invented speech'},
    ],
    elapsed_minutes:3,
    new_known_clue:isPrivate ? null : 'The bridge motes pulse in a patient three-beat rhythm.',
    entity_disposition:null,
  };
  response.writeHead(200, {'content-type':'application/json'}).end(JSON.stringify({
    id:`response-${providerInputs.length}`, output_text:JSON.stringify(result),
    usage:{input_tokens:600,input_tokens_details:{cached_tokens:0},output_tokens:160,total_tokens:760},
  }));
});

const providerPort = await listen(provider);
const portProbe = createServer(); const port = await listen(portProbe); await new Promise(resolve => portProbe.close(resolve));
let host;
try {
  host = await startHost({port,data,campaign,providerPort});
  const dm = await connect(port,'dm');
  const screen = await connect(port,'screen');
  const renn = await connect(port,'wayfolio',{player_id:'renn',player_name:'Renn Hazel',character_id:'renn',device_id:'turn-renn'});
  const yugen = await connect(port,'wayfolio',{player_id:'yugen',player_name:'Yūgen',character_id:'yugen',device_id:'turn-yugen'});
  dm.socket.send(JSON.stringify({type:'dm_introduce_party_member',character_id:'yugen'}));
  await dm.next(message => message.type === 'party_member_introduced' && message.character_id === 'yugen');
  dm.socket.send(JSON.stringify({type:'dm_journey_start'}));
  await dm.next(message => message.type === 'journey_started');

  const publicDeclaration = 'I inspect the blue motes for a pattern without touching them.';
  const publicActionID = crypto.randomUUID();
  yugen.socket.send(JSON.stringify({type:'action_submit',client_action_id:publicActionID,player_id:'yugen',author:'Yūgen',text:publicDeclaration,visibility:'public'}));
  await yugen.next(message => message.type === 'action_ack' && message.client_action_id === publicActionID);
  await screen.next(message => message.type === 'action_event' && message.text === publicDeclaration);
  assert.equal(renn.messages.some(message => message.type === 'action_event' && message.text === publicDeclaration), false,
    'Another player phone must not receive Yūgen’s action-log event.');
  const publicCommit = await dm.next(message => (message.type === 'turn_committed' && message.transaction.declaration === publicDeclaration)
    || message.type === 'review_status');
  assert.equal(publicCommit.type,'turn_committed',publicCommit.message);
  assert.equal(Boolean(publicCommit.transaction.roll),false,'Low-stakes observation should not require a die roll.');
  assert.equal(publicCommit.transaction.status,'COMMITTED');
  await yugen.next(message => message.type === 'private_result' && message.detail.includes('patient observation'));
  assert.equal(screen.messages.some(message => message.type === 'private_result'), false,
    'The shared screen must not receive character-private findings.');
  const yugenState = await yugen.next(message => message.type === 'session_snapshot'
    && message.character_state?.discoveries?.includes('The bridge motes pulse in a patient three-beat rhythm.'));
  assert.equal(yugenState.character_state.inventory.includes('Dōkontō, the Soul-Guiding Lantern'), true);
  assert.equal(providerInputs[0].actor_id,'yugen');
  assert.deepEqual(new Set(providerInputs[0].world.party.filter(member => member.present).map(member => member.id)),
    new Set(['renn','soren','lupin','yugen','hinosuke']));

  const privateDeclaration = 'I hand Soren a folded note privately.';
  const sharedSceneBeforePrivateTurn = publicCommit.transaction.public_narration;
  const privateActionID = crypto.randomUUID();
  renn.socket.send(JSON.stringify({type:'action_submit',client_action_id:privateActionID,player_id:'renn',author:'Renn',text:privateDeclaration,visibility:'private'}));
  await renn.next(message => message.type === 'action_ack' && message.client_action_id === privateActionID);
  const privateCommit = await dm.next(message => message.type === 'turn_committed' && message.transaction.declaration === privateDeclaration);
  assert.equal(privateCommit.transaction.public_narration.includes(privateDeclaration), false);
  assert.deepEqual(privateCommit.transaction.companion_lines,[]);
  assert.equal(screen.messages.some(message => message.type === 'action_event' && message.text === privateDeclaration), false);
  assert.equal(screen.messages.some(message => JSON.stringify(message).includes(privateDeclaration)), false,
    'Private declaration leaked to the shared screen.');
  assert.equal(screen.messages.some(message => message.type === 'scene_update'
    && message.scene_text === 'The externally visible situation holds while the Wayfolio DM resolves something privately.'), false,
    'A private action must not replace the shared scene.');
  const sharedAfterPrivateTurn = await screen.next(message => message.type === 'session_snapshot'
    && message.scene_text === sharedSceneBeforePrivateTurn);
  assert.equal(sharedAfterPrivateTurn.scene_text,sharedSceneBeforePrivateTurn);
  await renn.next(message => message.type === 'private_result' && message.detail.includes('Private answer for renn'));

  const privateCheck = 'I privately investigate the bridge stones for a concealed mechanism.';
  renn.socket.send(JSON.stringify({type:'action_submit',client_action_id:crypto.randomUUID(),player_id:'renn',
    author:'Renn',text:privateCheck,visibility:'private'}));
  const secretRoll = await dm.next(message => message.type === 'roll_requested' && message.roll?.choice === privateCheck);
  assert.equal(secretRoll.roll.secret,true);
  await dm.next(message => message.type === 'turn_committed' && message.transaction.declaration === privateCheck);
  assert.equal(screen.messages.some(message => JSON.stringify(message).includes(privateCheck)),false,
    'A private check or its roll prompt leaked to the shared screen.');

  dm.socket.send(JSON.stringify({type:'dm_start_monster_encounter'}));
  const encounterDM = await dm.next(message => message.type === 'session_snapshot'
    && message.active_encounter?.combatants?.some(combatant => combatant.id === 'gloam-hound'));
  assert.deepEqual(new Set(encounterDM.active_encounter.combatants.map(combatant => combatant.id)),
    new Set(['renn','yugen','soren','lupin','hinosuke','gloam-hound']));
  const encounterScreen = await screen.next(message => message.type === 'session_snapshot'
    && message.active_encounter?.combatants?.some(combatant => combatant.id === 'gloam-hound'));
  const publicMonster = encounterScreen.active_encounter.combatants.find(combatant => combatant.id === 'gloam-hound');
  assert.equal(publicMonster.hp_visibility,false);
  assert.equal(publicMonster.hp,0);

  for (const connection of [dm,screen,renn,yugen]) connection.socket.close();
  await stopHost(host); host = null;

  host = await startHost({port,data,campaign,providerPort});
  const restoredDM = await connect(port,'dm');
  const restoredYugen = await connect(port,'wayfolio',{player_id:'yugen',player_name:'Yūgen',character_id:'yugen',device_id:'turn-yugen'});
  const restored = await restoredDM.next(message => message.type === 'session_snapshot' && message.transactions?.length >= 3);
  assert.equal(restored.journey_live,true,'An active journey should remain live across a normal Host restart.');
  assert.equal(restored.storyteller_runtime.state_version >= 3,true);
  assert.equal(restored.world_state.party.some(member => member.id === 'yugen' && member.present),true);
  assert.equal(restored.world_state.party.some(member => member.id === 'hinosuke' && member.present),true);
  const restoredPlayer = await restoredYugen.next(message => message.type === 'session_snapshot'
    && message.character_state?.discoveries?.includes('The bridge motes pulse in a patient three-beat rhythm.'));
  assert.equal(restoredPlayer.character.id,'yugen');
  restoredDM.socket.send(JSON.stringify({type:'dm_journey_continue'}));
  const resumed = await restoredDM.next(message => message.type === 'journey_continued');
  assert.deepEqual(new Set(resumed.character_ids),new Set(['renn','yugen']));
  restoredDM.socket.close(); restoredYugen.socket.close();
  console.log('Two-player open-play turn, privacy, player sovereignty, per-character knowledge, and restart autosave passed.');
} finally {
  if (host) await stopHost(host);
  provider.close();
  await rm(temporary,{recursive:true,force:true});
}
