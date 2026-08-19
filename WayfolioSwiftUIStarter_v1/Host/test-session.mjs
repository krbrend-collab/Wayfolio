import {WebSocket} from 'ws';

const port = Number(process.env.HOST_PORT || 8787);
const baseURL = `http://localhost:${port}`;

class Inbox {
  constructor(socket) {
    this.messages = [];
    this.waiters = [];
    socket.on('message', raw => {
      const message = JSON.parse(raw);
      const index = this.waiters.findIndex(waiter => waiter.predicate(message));
      if (index >= 0) this.waiters.splice(index, 1)[0].resolve(message);
      else this.messages.push(message);
    });
  }

  next(predicate, timeout = 3000) {
    const index = this.messages.findIndex(predicate);
    if (index >= 0) return Promise.resolve(this.messages.splice(index, 1)[0]);
    return new Promise((resolve, reject) => {
      const waiter = {predicate, resolve};
      this.waiters.push(waiter);
      setTimeout(() => {
        const position = this.waiters.indexOf(waiter);
        if (position >= 0) this.waiters.splice(position, 1);
        reject(new Error('Timed out waiting for a session message.'));
      }, timeout);
    });
  }
}

async function open(role, player = false) {
  const socket = new WebSocket(`ws://localhost:${port}/session`);
  const inbox = new Inbox(socket);
  await new Promise((resolve, reject) => {
    socket.once('open', resolve);
    socket.once('error', reject);
  });
  socket.send(JSON.stringify({
    type:'join', role, session_code:'HEMLOCK',
    ...(player ? {player_id:'renn', player_name:'Renn'} : {}),
  }));
  await inbox.next(message => message.type === 'joined');
  return {socket, inbox};
}

const dm = await open('dm');
const screen = await open('screen');
const renn = await open('wayfolio', true);

const catalogResponse = await fetch(`${baseURL}/audio-catalog.json`);
const audioResponse = await fetch(`${baseURL}/Audio/SFX/Creature/Form/slime_curious_move.wav`);
if (!catalogResponse.ok || !(await catalogResponse.json()).cues?.length) throw new Error('Audio catalog route failed.');
if (!audioResponse.ok || (await audioResponse.arrayBuffer()).byteLength < 1000) throw new Error('Audio asset route failed.');

dm.socket.send(JSON.stringify({type:'dm_presentation', event:{
  type:'creature_sound', creature_id:'glimmer_slime', creature_type:'ooze',
  body_form:'amorphous', size:'small', disposition:'curious', behavior:'move',
}}));
const creatureEvent = await screen.inbox.next(message => message.type === 'presentation_event');
if (creatureEvent.audience?.kind !== 'shared' || creatureEvent.event.behavior !== 'move') {
  throw new Error('Semantic creature presentation event was not routed to the shared screen.');
}
let creatureLeaked = false;
try {
  await renn.inbox.next(message => message.type === 'presentation_event', 300);
  creatureLeaked = true;
} catch {}
if (creatureLeaked) throw new Error('Shared creature audio leaked to a Wayfolio.');

dm.socket.send(JSON.stringify({type:'dm_presentation', event:{
  type:'ambience', action:'play', cue:'hemlock_forest', volume:0.5,
}}));
await screen.inbox.next(message => message.type === 'presentation_event' && message.event.type === 'ambience');
const reconnectingScreen = await open('screen');
const restored = await reconnectingScreen.inbox.next(message => message.type === 'session_snapshot');
if (restored.presentation_state?.ambience?.cue !== 'hemlock_forest') {
  throw new Error('Persistent ambience was not restored for a reconnecting shared screen.');
}
reconnectingScreen.socket.close();

async function check(mode, physicalDie) {
  const checkStartedAt = Date.now();
  dm.socket.send(JSON.stringify({
    type:'dm_prompt', player_id:'renn', title:'Roll test', message:'Choose', choices:['Act'],
    skill:'Insight', dc:12, modifier:3,
  }));
  const prompt = await renn.inbox.next(message => message.type === 'private_prompt');
  renn.socket.send(JSON.stringify({
    type:'player_choice', prompt_id:prompt.prompt_id, choice:'Act',
  }));
  const request = await screen.inbox.next(message => message.type === 'roll_requested');
  screen.socket.send(JSON.stringify({
    type:'roll_submit', roll_id:request.roll.id, mode,
    ...(physicalDie ? {die:physicalDie} : {}),
  }));
  await renn.inbox.next(message => message.type === 'private_result');
  const snapshot = await screen.inbox.next(message =>
    message.type === 'session_snapshot' && message.last_result?.mode === mode &&
    Date.parse(message.last_result.at) >= checkStartedAt
  );
  if (mode === 'physical' && snapshot.last_result.die !== physicalDie) {
    throw new Error('The physical die face was not preserved.');
  }
  if (snapshot.last_result.die < 1 || snapshot.last_result.die > 20) {
    throw new Error('The resolved d20 is out of range.');
  }
}

await check('physical', 17);
await check('digital');

dm.socket.send(JSON.stringify({type:'dm_start_encounter'}));
const encounterPrompt = await renn.inbox.next(message =>
  message.type === 'private_prompt' && message.title.includes('Renn')
);
renn.socket.send(JSON.stringify({
  type:'player_choice', prompt_id:encounterPrompt.prompt_id,
  choice:'Study them from a distance',
}));
const encounterRoll = await screen.inbox.next(message =>
  message.type === 'roll_requested' && message.roll.encounterID === 'hemlock-bridge'
);
if (encounterRoll.roll.skill !== 'Nature' || encounterRoll.roll.modifier !== 3 || encounterRoll.roll.dc !== 11) {
  throw new Error('The bridge choice did not use Renn’s canonical Nature check.');
}
screen.socket.send(JSON.stringify({
  type:'roll_submit', roll_id:encounterRoll.roll.id, mode:'physical', die:20,
}));
const privateResult = await renn.inbox.next(message =>
  message.type === 'private_result' && message.detail.includes('lantern keeper')
);
if (!privateResult.succeeded) throw new Error('The guaranteed bridge success failed.');
const rennSnapshot = await renn.inbox.next(message =>
  message.type === 'session_snapshot' &&
  message.character_state?.discoveries?.includes('Whisper Beneath the Hemlock Bridge')
);
if (rennSnapshot.character?.name !== 'Renn Hazel') {
  throw new Error('Renn’s canonical character was not delivered to the Wayfolio.');
}
const publicSnapshot = await screen.inbox.next(message =>
  message.type === 'session_snapshot' && message.last_result?.choice === 'Study them from a distance'
);
if (publicSnapshot.character || publicSnapshot.character_state) {
  throw new Error('Private Wayfolio character data leaked onto the shared screen.');
}

renn.socket.send(JSON.stringify({type:'action_submit', player_id:'renn', author:'Renn',
  text:'I quietly inspect the southern rail.', visibility:'private'}));
const privateAction = await dm.inbox.next(message =>
  message.type === 'action_event' && message.text.includes('southern rail')
);
if (privateAction.visibility !== 'private') throw new Error('Private action lost its audience.');
let privateLeaked = false;
try {
  await screen.inbox.next(message => message.type === 'action_event' && message.text.includes('southern rail'), 300);
  privateLeaked = true;
} catch {}
if (privateLeaked) throw new Error('A private action leaked to the shared screen.');

renn.socket.send(JSON.stringify({type:'action_submit', player_id:'renn', author:'Renn',
  text:'I call everyone toward the bridge.', visibility:'public'}));
await Promise.all([
  dm.inbox.next(message => message.type === 'action_event' && message.text.includes('everyone')),
  screen.inbox.next(message => message.type === 'action_event' && message.text.includes('everyone')),
]);

for (const connection of [dm, screen, renn]) connection.socket.close();
console.log('Audio routing, dice, Renn encounter, persistence, and private/public actions passed.');
