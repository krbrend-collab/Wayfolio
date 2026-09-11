import {mkdtemp, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {WebSocket} from 'ws';

const directory = await mkdtemp(join(tmpdir(), 'wayfolio-knowledge-'));
const statePath = join(directory, 'campaign-state.json');
await writeFile(statePath, JSON.stringify({activeJourneyID:'renn-intro-tutorial', story:{source_revision:0},
  currentDialogue:{type:'dialogue', line_id:'legacy-stale-line', speaker_id:'lupin',
    text:'This legacy line must not occupy the shared screen after restart.'}}));
const port = 8974;
const server = spawn(process.execPath, ['server.mjs'], {cwd:new URL('.', import.meta.url), env:{...process.env,
  PORT:String(port), WAYFOLIO_DATA_DIRECTORY:directory, WAYFOLIO_SESSION_STATE_PATH:statePath}});

class Inbox {
  constructor(socket) {
    this.messages = [];
    this.waiters = [];
    socket.on('message', raw => {
      const message = JSON.parse(raw);
      const waiter = this.waiters.find(item => item.predicate(message));
      if (waiter) { this.waiters.splice(this.waiters.indexOf(waiter), 1); waiter.resolve(message); }
      else this.messages.push(message);
    });
  }
  next(predicate, timeout = 5000) {
    const index = this.messages.findIndex(predicate);
    if (index >= 0) return Promise.resolve(this.messages.splice(index, 1)[0]);
    return new Promise((resolve, reject) => {
      const waiter = {predicate, resolve}; this.waiters.push(waiter);
      setTimeout(() => reject(new Error('Timed out waiting for journey knowledge.')), timeout);
    });
  }
}

async function joinRole(role, suffix = '') {
  const socket = new WebSocket(`ws://localhost:${port}/session`);
  const inbox = new Inbox(socket);
  await new Promise((resolve, reject) => { socket.once('open', resolve); socket.once('error', reject); });
  socket.send(JSON.stringify({type:'join', role, session_code:'HEMLOCK', ...(role === 'wayfolio' ? {
    player_id:'renn', player_name:'Renn', character_id:'renn', device_id:`knowledge-${suffix}`,
  } : {})}));
  await inbox.next(message => message.type === 'joined');
  return {socket, inbox};
}

try {
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(resolve, 700);
    server.once('exit', code => { clearTimeout(timeout); reject(new Error(`Host exited before testing (${code}).`)); });
  });
  const player = await joinRole('wayfolio', 'player');
  const playerState = await player.inbox.next(message => message.type === 'session_snapshot' && message.campaign_knowledge);
  const knowledge = playerState.campaign_knowledge;
  for (const [key, minimum] of Object.entries({locations:3, people:3, creatures:1, botanicals:3, recipes:2, completed_work:6})) {
    if (!Array.isArray(knowledge[key]) || knowledge[key].length < minimum) throw new Error(`${key} was not projected from tutorial state.`);
  }
  if (knowledge.creatures.some(record => ['gloam-hound', 'mimic-slime', 'crown-hare'].includes(record.id))) {
    throw new Error('An unencountered sample creature leaked into tutorial knowledge.');
  }
  if (playerState.location_id !== 'location_creature_care_center'
      || playerState.scene_context_id !== 'main_interior'
      || playerState.scene_title !== 'Hemlock Creature Care Center') {
    throw new Error('The Renn tutorial did not hydrate the WF-089 Creature Care Center presentation context.');
  }
  if (!knowledge.locations.some(record => record.id === 'location_creature_care_center' && record.status === 'current')) {
    throw new Error('The current Creature Care Center record was not projected into Renn’s Wayfolio.');
  }

  const dm = await joinRole('dm');
  const dmState = await dm.inbox.next(message => message.type === 'session_snapshot' && message.world_state);
  if (dmState.current_dialogue) {
    throw new Error('A legacy dialogue without presentation time was restored after restart.');
  }
  const rowan = dmState.world_state.active_entities.find(record => record.id === 'unbound-rowan-reference');
  if (!rowan || dmState.world_state.party.some(record => record.id === 'npc_mair_rowan')) {
    throw new Error('The current Rowan reference was incorrectly bound to Mair Rowan in active world state.');
  }
  const presentParty = dmState.world_state.party.filter(record => record.present).map(record => record.id);
  if (presentParty.length !== 1 || presentParty[0] !== 'renn') {
    throw new Error(`The tutorial scene leaked absent party members: ${presentParty.join(', ')}`);
  }
  if (dmState.world_state.active_entities.some(record => ['bridge-motes', 'crown-hare'].includes(record.id))) {
    throw new Error('Hemlock Bridge entities leaked into the Creature Care Center scene.');
  }
  dm.socket.send(JSON.stringify({type:'dm_presentation', event:{type:'dialogue', line_id:'reconnect-continuity-line', speaker_id:'soren',
    speaker_name:'Soren Hazel', text:'Reconnect continuity check.'}}));
  await new Promise(resolve => setTimeout(resolve, 100));
  const screen = await joinRole('screen');
  const screenState = await screen.inbox.next(message => message.type === 'session_snapshot');
  if (screenState.current_dialogue?.text !== 'Reconnect continuity check.' || screenState.current_dialogue?.speaker_id !== 'soren') {
    throw new Error('The shared screen did not receive the last staged dialogue on reconnect.');
  }
  if (!screenState.current_dialogue?.presented_at) {
    throw new Error('The staged dialogue does not include presentation expiry metadata.');
  }
  screen.socket.send(JSON.stringify({type:'presentation_ack', line_id:screenState.current_dialogue.line_id,
    speaker_id:'soren', status:'completed'}));
  await new Promise(resolve => setTimeout(resolve, 100));
  const resumedScreen = await joinRole('screen');
  const resumedState = await resumedScreen.inbox.next(message => message.type === 'session_snapshot');
  if (resumedState.current_dialogue) {
    throw new Error('A completed dialogue portrait and caption were restored on reconnect.');
  }
  for (const connection of [player, dm, screen, resumedScreen]) connection.socket.close();
  console.log('Journey knowledge and shared-screen reconnect continuity passed.');
} finally {
  server.kill('SIGTERM');
}
