import {WebSocket} from 'ws';

const port = Number(process.env.HOST_PORT || 8788);

async function connect(role) {
  const socket = new WebSocket(`ws://localhost:${port}/session`);
  const messages = [];
  const waiters = [];
  socket.on('message', raw => {
    const message = JSON.parse(raw);
    const waiter = waiters.find(item => item.predicate(message));
    if (waiter) {
      waiters.splice(waiters.indexOf(waiter), 1);
      waiter.resolve(message);
    } else messages.push(message);
  });
  await new Promise((resolve, reject) => { socket.once('open', resolve); socket.once('error', reject); });
  const next = (predicate, timeout = 1500) => {
    const index = messages.findIndex(predicate);
    if (index >= 0) return Promise.resolve(messages.splice(index, 1)[0]);
    return new Promise((resolve, reject) => {
      const waiter = {predicate, resolve};
      waiters.push(waiter);
      setTimeout(() => {
        const current = waiters.indexOf(waiter);
        if (current >= 0) waiters.splice(current, 1);
        reject(new Error('Timed out waiting for directed audio.'));
      }, timeout);
    });
  };
  socket.send(JSON.stringify({type:'join', role, session_code:'HEMLOCK'}));
  await next(message => message.type === 'joined');
  return {socket, next};
}

const dm = await connect('dm');
const screen = await connect('screen');

dm.socket.send(JSON.stringify({type:'dm_scene', scene_title:'The Old Road', scene_text:'A gravel trail winds onward.'}));
dm.socket.send(JSON.stringify({type:'dm_presentation', event:{type:'audio_director', context:'action', text:'We sneak quietly forward.'}}));
const movement = await screen.next(message => message.type === 'presentation_event' && message.event.cue === 'movement_gravel');
if (movement.event.volume >= 0.4) throw new Error('Sneaking was not quieter than walking.');

dm.socket.send(JSON.stringify({type:'dm_presentation', event:{type:'audio_director', context:'action', text:'I open the door carefully.'}}));
await screen.next(message => message.type === 'presentation_event' && message.event.cue === 'door_latch');

dm.socket.send(JSON.stringify({type:'dm_presentation', event:{type:'audio_director', context:'action', text:'I inspect the old carving.'}}));
await dm.next(message => message.type === 'error' && message.message.includes('Invalid presentation'));

dm.socket.close();
screen.socket.close();
console.log('Audio director surface context, priority, and silence fallback passed.');
