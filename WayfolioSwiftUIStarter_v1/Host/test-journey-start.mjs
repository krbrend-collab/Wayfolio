import {WebSocket} from 'ws';

const port = Number(process.env.PORT || 8787);

async function connect(role, extra = {}) {
  const socket = new WebSocket(`ws://127.0.0.1:${port}/session`);
  const messages = [];
  const waiters = [];
  socket.on('message', raw => {
    const value = JSON.parse(raw);
    const index = waiters.findIndex(waiter => waiter.predicate(value));
    if (index >= 0) waiters.splice(index, 1)[0].resolve(value);
    else messages.push(value);
  });
  const next = (predicate, timeout = 3000) => {
    const index = messages.findIndex(predicate);
    if (index >= 0) return Promise.resolve(messages.splice(index, 1)[0]);
    return new Promise((resolve, reject) => {
      const waiter = {predicate, resolve}; waiters.push(waiter);
      setTimeout(() => {
        const position = waiters.indexOf(waiter); if (position >= 0) waiters.splice(position, 1);
        reject(new Error('Timed out waiting for a journey-start message.'));
      }, timeout);
    });
  };
  await new Promise((resolve, reject) => { socket.once('open', resolve); socket.once('error', reject); });
  socket.send(JSON.stringify({type:'join', role, session_code:'HEMLOCK', ...extra}));
  await next(message => message.type === 'joined');
  return {socket, next};
}

const dm = await connect('dm');
await dm.next(message => message.type === 'session_snapshot');
dm.socket.send(JSON.stringify({type:'dm_journey_start'}));
const missingPlayer = await dm.next(message => message.type === 'error');
if (!missingPlayer.message.includes('at least one player Wayfolio')) throw new Error('Missing-player start guidance failed.');

const player = await connect('wayfolio', {player_id:'renn', player_name:'Renn Hazel', character_id:'renn', device_id:'journey-start-test'});
await player.next(message => message.type === 'session_snapshot');
const roster = await dm.next(message => message.type === 'session_snapshot' &&
  message.character_catalog?.some(character => character.id === 'renn' && character.connected));
if (!roster) throw new Error('Connected Wayfolio was not reflected in the DM roster.');

dm.socket.send(JSON.stringify({type:'dm_journey_start'}));
const started = await dm.next(message => message.type === 'journey_started');
if (started.players[0] !== 'Renn Hazel') throw new Error('The active player name was not acknowledged.');
const active = await dm.next(message => message.type === 'session_snapshot' && message.open_play_active);
if (!active.story_state?.active_character_ids?.includes('renn')) throw new Error('The active journey roster was not recorded.');
if (active.story_state.checkpoint !== 'lantern_road_arrival' || active.scene_title !== 'The Lantern Road') {
  throw new Error('A new journey did not receive its opening scene.');
}
dm.socket.send(JSON.stringify({type:'dm_journey_continue'}));
await dm.next(message => message.type === 'journey_continued');
const continued = await dm.next(message => message.type === 'session_snapshot' && message.journey_live);
if (continued.scene_title !== active.scene_title || continued.story_state.checkpoint !== active.story_state.checkpoint) {
  throw new Error('Continuing the journey reset or replayed the saved scene.');
}

player.socket.close(); dm.socket.close();
console.log('Journey start and active-player presence passed.');
