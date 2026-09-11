import {readFile} from 'node:fs/promises';
import {WebSocket} from 'ws';

const port = Number(process.env.HOST_PORT || 8787);
const statePath = process.env.WAYFOLIO_SESSION_STATE_PATH;
if (!statePath) throw new Error('WAYFOLIO_SESSION_STATE_PATH is required.');

const saved = JSON.parse(await readFile(statePath, 'utf8'));
const assignment = saved.playerRegistry?.find(player => player.id === 'renn');
if (!assignment?.resume_token || !assignment?.device_id) throw new Error('Saved Renn assignment is incomplete.');

function join(payload) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(`ws://127.0.0.1:${port}/session`);
    const messages = [];
    const timer = setTimeout(() => reject(new Error('Reconnect test timed out.')), 3000);
    socket.on('open', () => socket.send(JSON.stringify({
      type:'join', role:'wayfolio', session_code:'HEMLOCK', player_id:'renn', player_name:'Renn', character_id:'renn', ...payload,
    })));
    socket.on('message', raw => {
      const message = JSON.parse(raw);
      messages.push(message);
      const complete = message.type === 'error'
        || (messages.some(value => value.type === 'joined') && messages.some(value => value.type === 'session_snapshot'));
      if (complete) {
        clearTimeout(timer);
        socket.close();
        resolve(messages);
      }
    });
    socket.on('error', reject);
  });
}

const resumed = await join({device_id:assignment.device_id, resume_token:assignment.resume_token});
const joined = resumed.find(message => message.type === 'joined');
const snapshot = resumed.find(message => message.type === 'session_snapshot');
if (!joined?.resumed || joined.resume_token !== assignment.resume_token || snapshot?.character?.name !== 'Renn Hazel') {
  throw new Error('The assigned Wayfolio did not resume after host restart.');
}

const rejected = await join({device_id:'unassigned-second-device'});
if (!rejected.some(message => message.type === 'error' && message.message.includes('assigned to another Wayfolio'))) {
  throw new Error('A different device was able to claim Renn.');
}

console.log('Persistent assignment, authorized restart recovery, and duplicate-device rejection passed.');
