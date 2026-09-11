import {WebSocket} from 'ws';

const port = Number(process.env.HOST_PORT || 8787);
const sockets = [];
const inboxes = new Map();

function connect(role, extra = {}) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(`ws://127.0.0.1:${port}/session`);
    sockets.push(socket); inboxes.set(socket, []);
    const timer = setTimeout(() => reject(new Error(`Timed out joining ${role}`)), 3000);
    socket.on('open', () => socket.send(JSON.stringify({type:'join', role, session_code:'HEMLOCK', ...extra})));
    socket.on('message', raw => {
      const message = JSON.parse(raw); inboxes.get(socket).push(message);
      if (message.type === 'joined') { clearTimeout(timer); resolve({socket, joined:message}); }
      if (message.type === 'error') { clearTimeout(timer); reject(new Error(message.message)); }
    });
    socket.on('error', reject);
  });
}

async function waitFor(socket, predicate, label, timeout = 4000) {
  const existing = inboxes.get(socket).find(predicate);
  if (existing) return existing;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`Timed out waiting for ${label}`)), timeout);
    const listener = raw => {
      const value = JSON.parse(raw);
      if (predicate(value)) { clearTimeout(timer); socket.off('message', listener); resolve(value); }
    };
    socket.on('message', listener);
  });
}

const info = await fetch(`http://127.0.0.1:${port}/session-info.json`).then(response => response.json());
const playableIDs = new Set(info.characters.map(character => character.id));
if (!playableIDs.has('renn') || [...playableIDs].some(id => !['renn','yugen'].includes(id))
    || !info.join_url.startsWith('wayfolio://join?')) {
  throw new Error('The player catalog must contain only approved player characters and must never offer companions.');
}
const qr = await fetch(`http://127.0.0.1:${port}/join-qr.svg`).then(response => response.text());
if (!qr.includes('<svg')) throw new Error('Join QR was not generated.');

const dm = await connect('dm');
const screen = await connect('screen');
const renn = await connect('wayfolio', {player_id:'renn', player_name:'Renn', character_id:'renn', device_id:'renn-old'});
if (!renn.joined.resume_token) throw new Error('The player Wayfolio did not receive resume credentials.');

renn.socket.send(JSON.stringify({type:'character_transfer_request'}));
const transfer = await waitFor(renn.socket, value => value.type === 'character_transfer_ready', 'transfer code');
const movedRenn = await connect('wayfolio', {player_id:'renn', player_name:'Renn', character_id:'renn', device_id:'renn-new', transfer_code:transfer.transfer_code});
if (movedRenn.joined.resume_token === renn.joined.resume_token) throw new Error('Transfer did not rotate credentials.');

dm.socket.send(JSON.stringify({type:'dm_start_monster_encounter'}));
const started = await waitFor(screen.socket, value => value.type === 'session_snapshot' && value.active_encounter?.status === 'active', 'encounter start');
if (started.active_encounter.active_combatant_id !== 'renn') throw new Error('NPC companion turns should advance automatically to the human player.');
movedRenn.socket.send(JSON.stringify({type:'action_submit', player_id:'renn', author:'renn', text:'I calmly offer peace and ask the hound to let us pass.', visibility:'public'}));
const roll = await waitFor(screen.socket, value => value.type === 'roll_requested' && value.roll?.storyBeat === 'monster_encounter', 'encounter roll');
screen.socket.send(JSON.stringify({type:'roll_submit', roll_id:roll.roll.id, mode:'physical', die:20}));
const resolved = await waitFor(screen.socket, value => value.type === 'session_snapshot' && value.active_encounter?.status === 'resolved', 'encounter resolution');
if (resolved.active_encounter.outcome !== 'calm') throw new Error('Noncombat encounter outcome did not resolve.');
if (resolved.players.some(player => 'device_id' in player || 'resume_token' in player)) throw new Error('Private device credentials leaked publicly.');

for (const socket of sockets) socket.close();
console.log('QR join, player Wayfolio, NPC companions, secure transfer, privacy, initiative, physical dice, and noncombat encounter resolution passed.');
