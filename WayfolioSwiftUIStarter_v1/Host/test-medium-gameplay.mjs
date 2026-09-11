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
    const next = (predicate, timeout = 15_000) => {
      const index = messages.findIndex(predicate);
      if (index >= 0) return Promise.resolve(messages.splice(index, 1)[0]);
      return new Promise((resolveNext, rejectNext) => {
        const waiter = {predicate, resolve:resolveNext}; waiters.push(waiter);
        const timer = setTimeout(() => {
          const position = waiters.indexOf(waiter); if (position >= 0) waiters.splice(position, 1);
          rejectNext(new Error(`Timed out waiting for ${role}. Recent: ${messages.slice(-12).map(item => item.type).join(', ')}`));
        }, timeout); timer.unref?.();
      });
    };
    socket.once('error', reject);
    socket.once('open', async () => {
      socket.send(JSON.stringify({type:'join', role, session_code:'HEMLOCK', ...extra}));
      const joined = await next(message => message.type === 'joined'); resolve({socket, next, messages, joined});
    });
  });
}

async function startHost({port, data, campaign, providerPort}) {
  const child = spawn(process.execPath, ['server.mjs'], {cwd:new URL('.', import.meta.url), env:{...process.env,
    PORT:String(port), WAYFOLIO_DATA_DIRECTORY:data, WAYFOLIO_CAMPAIGN_PATH:campaign,
    WAYFOLIO_OPENAI_BASE_URL:`http://127.0.0.1:${providerPort}/v1`,
    OPENAI_API_KEY:'sk-medium-gameplay-test-12345678901234567890'}, stdio:['ignore','pipe','pipe']});
  child.stderr.on('data', chunk => process.stderr.write(`[medium host] ${chunk}`));
  await new Promise((resolve, reject) => {
    let output = '';
    const timer = setTimeout(() => reject(new Error(`Host did not start. ${output}`)), 15_000);
    child.stdout.on('data', chunk => { output += chunk; if (output.includes('Wayfolio host:')) { clearTimeout(timer); resolve(); } });
    child.stderr.on('data', chunk => { output += chunk; });
    child.once('exit', code => { clearTimeout(timer); reject(new Error(`Host exited ${code}. ${output}`)); });
  });
  return child;
}

async function stopHost(child) {
  child.kill('SIGTERM');
  await new Promise(resolve => child.once('exit', resolve));
}

const temporary = await mkdtemp(join(tmpdir(), 'wayfolio-medium-gameplay-'));
const campaign = join(temporary, 'campaign'); const data = join(temporary, 'data');
await cp(new URL('../Campaigns/HemlockDevelopment/', import.meta.url), campaign, {recursive:true});
const providerInputs = [];
const provider = createServer(async (request, response) => {
  if (request.url === '/v1/models') return response.writeHead(200, {'content-type':'application/json'}).end(JSON.stringify({data:[]}));
  if (request.url !== '/v1/responses') return response.writeHead(404).end();
  const chunks = []; for await (const chunk of request) chunks.push(chunk);
  const payload = JSON.parse(Buffer.concat(chunks).toString('utf8'));
  const input = JSON.parse(payload.input); providerInputs.push(input);
  const result = {public_narration:'Rowan looks up from the worktable and listens as Renn explains the urgent situation.',
    private_information:'Renn can continue speaking freely; Rowan has not yet been bound to any existing NPC record.',
    companion_lines:[{speaker_id:'unbound-rowan-reference',text:'Tell me where the slime is hurt, and start from the beginning.',
      performance:'calm, attentive, ready to help'}], elapsed_minutes:1,
    new_known_clue:'Rowan is willing to hear Renn out.', entity_disposition:null};
  response.writeHead(200, {'content-type':'application/json'}).end(JSON.stringify({id:`medium-${providerInputs.length}`,
    output_text:JSON.stringify(result), usage:{input_tokens:500,output_tokens:100,total_tokens:600}}));
});

const providerPort = await listen(provider);
const portProbe = createServer(); const port = await listen(portProbe); await new Promise(resolve => portProbe.close(resolve));
let host;
try {
  host = await startHost({port,data,campaign,providerPort});
  const selected = await fetch(`http://127.0.0.1:${port}/api/launcher-library`, {method:'POST',
    headers:{'content-type':'application/json'}, body:JSON.stringify({journey_id:'renn-intro-tutorial'})});
  assert.equal(selected.ok,true,await selected.text());
  let dm = await connect(port,'dm'); let screen = await connect(port,'screen');
  let renn = await connect(port,'wayfolio',{player_id:'renn',player_name:'Renn Hazel',character_id:'renn',device_id:'medium-renn'});
  const initial = await dm.next(message => message.type === 'session_snapshot' && message.active_journey_id === 'renn-intro-tutorial');
  assert.equal(initial.location_id,'location_creature_care_center');
  assert.equal(initial.scene_context_id,'main_interior');
  assert.equal(initial.world_state.active_entities.some(entity => entity.id === 'unbound-rowan-reference'),true);
  assert.equal(initial.world_state.active_entities.some(entity => entity.id === 'npc_mair_rowan'),false);
  dm.socket.send(JSON.stringify({type:'dm_journey_continue'}));
  await dm.next(message => message.type === 'journey_continued');
  const restoredScene = await screen.next(message => message.type === 'scene_update'
    && message.location_id === 'location_creature_care_center');
  assert.equal(restoredScene.scene_context_id,'main_interior');
  const ambience = await screen.next(message => message.type === 'presentation_event'
    && message.event?.type === 'ambience_scene');
  assert.equal(ambience.event.profile,'village_day');

  const declaration = 'I ask Rowan for help with the injured slime at the pine-root path.';
  renn.socket.send(JSON.stringify({type:'action_submit',client_action_id:crypto.randomUUID(),player_id:'renn',
    author:'Renn',text:declaration,visibility:'public'}));
  const committed = await dm.next(message => (message.type === 'turn_committed' && message.transaction.declaration === declaration)
    || (message.type === 'roll_requested' && message.roll?.choice === declaration));
  assert.equal(committed.type,'turn_committed','Ordinary conversation must proceed without a roll.');
  assert.equal(screen.messages.some(message => message.type === 'roll_requested' && message.roll?.choice === declaration),false);
  assert.equal(providerInputs.length,1);
  assert.deepEqual(providerInputs[0].world.party.filter(member => member.present).map(member => member.id),['renn']);
  assert.equal(providerInputs[0].world.active_entities.some(entity => entity.id === 'unbound-rowan-reference'),true);
  assert.equal(providerInputs[0].world.active_entities.some(entity => entity.id === 'npc_mair_rowan'),false);
  assert.equal(committed.transaction.companion_lines[0].speaker_id,'unbound-rowan-reference');
  assert.equal(committed.transaction.companion_lines[0].speaker_name,'Rowan');
  assert.equal(committed.transaction.companion_lines[0].voice_profile_id,'unknown_voice');
  const rowanDialogue = await screen.next(message => message.type === 'presentation_event'
    && message.event?.type === 'dialogue' && message.event?.speaker_id === 'unbound-rowan-reference');
  assert.equal(rowanDialogue.event.speaker_name,'Rowan');
  assert.equal(rowanDialogue.event.voice_profile_id,'unknown_voice');
  const publishedKnowledge = await renn.next(message => message.type === 'session_snapshot'
    && message.campaign_knowledge?.records?.some(record => record.id === 'unbound-rowan-reference'));
  const rowanRecord = publishedKnowledge.campaign_knowledge.records.find(record => record.id === 'unbound-rowan-reference');
  assert.equal(rowanRecord.kind,'person');
  assert.equal(rowanRecord.notes.includes('Rowan is willing to hear Renn out.'),true);
  assert.equal(publishedKnowledge.campaign_knowledge.records.filter(record => record.id === 'unbound-rowan-reference').length,1);
  const savedScene = committed.transaction.public_narration;

  const unresolvedDeclaration = 'I force open the stuck iron service door despite the danger.';
  renn.socket.send(JSON.stringify({type:'action_submit',client_action_id:crypto.randomUUID(),player_id:'renn',
    author:'Renn',text:unresolvedDeclaration,visibility:'public'}));
  const unresolvedRoll = await screen.next(message => message.type === 'roll_requested'
    && message.roll?.choice === unresolvedDeclaration);

  for (const connection of [dm,screen,renn]) connection.socket.close();
  await stopHost(host); host = null;
  host = await startHost({port,data,campaign,providerPort});
  dm = await connect(port,'dm');
  renn = await connect(port,'wayfolio',{player_id:'renn',player_name:'Renn Hazel',character_id:'renn',device_id:'medium-renn'});
  const restored = await dm.next(message => message.type === 'session_snapshot'
    && message.transactions?.some(transaction => transaction.declaration === declaration));
  assert.equal(restored.journey_live,true);
  assert.equal(restored.scene_text,savedScene);
  assert.equal(restored.pending_roll?.id,unresolvedRoll.roll.id);
  assert.equal(restored.pending_roll?.choice,unresolvedDeclaration);

  const switched = await fetch(`http://127.0.0.1:${port}/api/launcher-library`, {method:'POST',
    headers:{'content-type':'application/json'}, body:JSON.stringify({journey_id:'hemlock-bridge'})});
  assert.equal(switched.ok,true,await switched.text());
  screen = await connect(port,'screen');
  dm.socket.send(JSON.stringify({type:'dm_open_play_start'}));
  await dm.next(message => ['open_play_started','journey_started'].includes(message.type));
  dm.socket.send(JSON.stringify({type:'dm_start_monster_encounter'}));
  let encounter = await dm.next(message => message.type === 'session_snapshot' && message.active_encounter?.status === 'active');
  assert.equal(encounter.active_encounter.combatants.some(combatant => combatant.id === 'gloam-hound'),true);
  assert.equal(encounter.active_encounter.outcomes.includes('calm'),true);
  assert.equal(encounter.active_encounter.outcomes.includes('retreat'),true);
  const publicEncounter = await screen.next(message => message.type === 'session_snapshot' && message.active_encounter?.status === 'active');
  const hiddenMonster = publicEncounter.active_encounter.combatants.find(combatant => combatant.id === 'gloam-hound');
  assert.equal(hiddenMonster.hp_visibility,false); assert.equal(hiddenMonster.hp,0);

  for (let attempts = 0; attempts < 8; attempts += 1) {
    const activeID = encounter.active_encounter.active_combatant_id;
    const activeSocket = activeID === 'renn' ? renn : null;
    if (!activeSocket) throw new Error('Only Renn should be active in the isolated one-player encounter.');
    const rennCombatant = encounter.active_encounter.combatants.find(combatant => combatant.id === 'renn');
    if (rennCombatant.hp < rennCombatant.maximum_hp) break;
    const text = 'I make a careful staff strike without deciding anyone else’s action.';
    activeSocket.socket.send(JSON.stringify({type:'action_submit',client_action_id:crypto.randomUUID(),player_id:'renn',author:'Renn',text,visibility:'public'}));
    const roll = await screen.next(message => message.type === 'roll_requested' && message.roll?.storyBeat === 'monster_encounter');
    screen.socket.send(JSON.stringify({type:'roll_submit',roll_id:roll.roll.id,mode:'physical',die:1,client_roll_submission_id:crypto.randomUUID()}));
    encounter = await dm.next(message => message.type === 'session_snapshot' && message.active_encounter?.status === 'active'
      && message.active_encounter.active_combatant_id === 'renn' && message.last_result?.choice === text);
  }
  assert.equal(encounter.active_encounter.combatants.find(combatant => combatant.id === 'renn')?.hp < 10,true);
  const beforeHealing = encounter.active_encounter.combatants.find(combatant => combatant.id === 'renn').hp;
  const potionCountBefore = encounter.character_state.inventory.filter(item => String(typeof item === 'string' ? item : item?.name)
    .toLowerCase().includes('potion of healing')).length;
  renn.socket.send(JSON.stringify({type:'action_submit',client_action_id:crypto.randomUUID(),player_id:'renn',author:'Renn',
    text:'I drink my Potion of Healing.',visibility:'public'}));
  const healing = await renn.next(message => message.type === 'private_result' && message.title === 'Healing applied');
  assert.match(healing.detail,/Potion used/);
  const healed = await dm.next(message => message.type === 'session_snapshot'
    && message.last_result?.mode === 'automatic'
    && /Potion of Healing/.test(message.last_result?.choice || ''));
  assert.equal(healed.last_result.total > 0,true);
  assert.equal(healed.active_encounter.log.some(entry => entry.includes('restores') && entry.includes('Renn')),true);
  const potionCountAfter = healed.character_state.inventory.filter(item => String(typeof item === 'string' ? item : item?.name)
    .toLowerCase().includes('potion of healing')).length;
  assert.equal(potionCountAfter,potionCountBefore - 1);
  assert.equal(healed.active_encounter.status,'active');
  assert.equal(healed.active_encounter.active_combatant_id,'renn');

  renn.socket.send(JSON.stringify({type:'action_submit',client_action_id:crypto.randomUUID(),player_id:'renn',author:'Renn',
    text:'I calmly offer peace and ask the hound to let us pass.',visibility:'public'}));
  const finalRoll = await screen.next(message => message.type === 'roll_requested' && message.roll?.storyBeat === 'monster_encounter');
  screen.socket.send(JSON.stringify({type:'roll_submit',roll_id:finalRoll.roll.id,mode:'physical',die:20,client_roll_submission_id:crypto.randomUUID()}));
  const resolved = await screen.next(message => message.type === 'session_snapshot' && message.active_encounter?.status === 'resolved');
  assert.equal(resolved.active_encounter.outcome,'calm');
  const finalPlayer = await renn.next(message => message.type === 'session_snapshot'
    && message.character_state?.journal?.some(entry => entry.includes('Gloam Hound')));
  assert.equal(finalPlayer.character_state.hp.current > 0,true);
  for (const connection of [dm,screen,renn]) connection.socket.close();
  console.log('Medium gameplay slice: continuity, automatic dialogue, presentation restore, autosave, encounter privacy, resource use, and peaceful resolution passed.');
} finally {
  if (host) await stopHost(host);
  provider.close();
  await rm(temporary,{recursive:true,force:true});
}
