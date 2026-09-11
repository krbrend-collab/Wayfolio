import {WebSocket} from 'ws';

if (process.env.WAYFOLIO_ALLOW_LEGACY_EXTERNAL_TEST !== '1' || !process.env.HOST_PORT) {
  throw new Error(
    'Legacy external-host test blocked. It can modify campaign data. Use npm run test:hands-off for the isolated suite.'
  );
}

const port = Number(process.env.HOST_PORT || 8787);

function connect(role, extra = {}) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(`ws://127.0.0.1:${port}/session`);
    const messages = [];
    const waiters = [];
    socket.on('message', raw => {
      const message = JSON.parse(raw);
      const index = waiters.findIndex(waiter => waiter.predicate(message));
      if (index >= 0) waiters.splice(index, 1)[0].resolve(message); else messages.push(message);
    });
    const next = (predicate, timeout = 8000) => {
      const index = messages.findIndex(predicate);
      if (index >= 0) return Promise.resolve(messages.splice(index, 1)[0]);
      return new Promise((resolveNext, rejectNext) => {
        const waiter = {predicate, resolve:resolveNext}; waiters.push(waiter);
        setTimeout(() => {
          const position = waiters.indexOf(waiter); if (position >= 0) waiters.splice(position, 1);
          rejectNext(new Error(`Timed out waiting for ${role} hands-off event.`));
        }, timeout);
      });
    };
    socket.once('error', reject);
    socket.once('open', async () => {
      socket.send(JSON.stringify({type:'join', role, session_code:'HEMLOCK', ...extra}));
      await next(message => message.type === 'joined'); resolve({socket, next, messages});
    });
  });
}

const dm = await connect('dm');
const screen = await connect('screen');
const player = await connect('wayfolio', {player_id:'renn', player_name:'Renn Hazel', character_id:'renn', device_id:'hands-off-test'});
await dm.next(message => message.type === 'session_snapshot' && message.hands_off_dm === true);
dm.socket.send(JSON.stringify({type:'dm_open_play_start'}));
await dm.next(message => ['open_play_started','journey_started','journey_continued'].includes(message.type));

const automaticID = crypto.randomUUID();
player.socket.send(JSON.stringify({type:'action_submit', client_action_id:automaticID, player_id:'renn', author:'Renn',
  text:'I walk toward Soren and ask what she can plainly see.', visibility:'public'}));
const ack = await player.next(message => message.type === 'action_ack' && message.client_action_id === automaticID);
if (ack.durable_status !== 'ACKNOWLEDGED' || !ack.server_sequence) throw new Error('Action was acknowledged before durable v2 recording.');
const automaticCommit = await dm.next(message => message.type === 'turn_committed' && message.transaction.declaration.includes('walk toward Soren'));
if (!automaticCommit.transaction.transaction_hash) throw new Error('Automatic no-roll action did not commit through Contract 1.1.');
if (automaticCommit.transaction.storyteller_receipt?.newStateVersion !== 1) throw new Error('Storyteller CommitReceipt was not attached to the canonical turn.');
const storytellerSnapshot = await dm.next(message => message.type === 'session_snapshot' && message.storyteller_runtime?.state_version === 1);
if (storytellerSnapshot.storyteller_runtime.protocol !== 'wayfolio.storyteller.v1') throw new Error('DM host did not expose the active storyteller protocol.');

player.socket.send(JSON.stringify({type:'action_submit', client_action_id:automaticID, player_id:'renn', author:'Renn',
  text:'I walk toward Soren and ask what she can plainly see.', visibility:'public'}));
const replay = await player.next(message => message.type === 'action_ack' && message.client_action_id === automaticID && message.replayed);
if (replay.action_id !== ack.action_id) throw new Error('Duplicate action did not return its original durable acknowledgement.');

const uncertainID = crypto.randomUUID();
player.socket.send(JSON.stringify({type:'action_submit', client_action_id:uncertainID, player_id:'renn', author:'Renn',
  text:'I carefully investigate whether someone concealed a mechanism beneath the bridge stones.', visibility:'private'}));
await player.next(message => message.type === 'action_ack' && message.client_action_id === uncertainID);
const roll = await screen.next(message => message.type === 'roll_requested' && message.roll?.proposalID);
if (!roll.roll.ruling_locked_at || !roll.roll.stakes) throw new Error('Roll was exposed before its ruling and stakes were locked.');
screen.socket.send(JSON.stringify({type:'roll_submit', roll_id:roll.roll.id, mode:'physical', die:16,
  client_roll_submission_id:crypto.randomUUID()}));
const committed = await dm.next(message => message.type === 'turn_committed' && message.transaction.declaration.includes('concealed a mechanism'));
if (committed.transaction.status !== 'COMMITTED') throw new Error('Hands-off rolled action did not commit automatically.');
const privateResult = await player.next(message => message.type === 'private_result');
if (!privateResult.detail) throw new Error('Acting Wayfolio did not receive its private result.');

const advantageID = crypto.randomUUID();
player.socket.send(JSON.stringify({type:'action_submit', client_action_id:advantageID, player_id:'renn', author:'Renn',
  text:"I investigate the bridge mechanism with Soren's help.", visibility:'public'}));
await player.next(message => message.type === 'action_ack' && message.client_action_id === advantageID);
const advantageRoll = await screen.next(message => message.type === 'roll_requested' && message.roll?.selection === 'advantage');
if (advantageRoll.roll.advantage_sources?.length !== 1) throw new Error('Advantage source was not locked and presented.');
const advantageSubmission = crypto.randomUUID();
screen.socket.send(JSON.stringify({type:'roll_submit', roll_id:advantageRoll.roll.id, mode:'physical', dice:[7,17],
  client_roll_submission_id:advantageSubmission}));
const advantageAck = await screen.next(message => message.type === 'roll_ack' && message.client_roll_submission_id === advantageSubmission);
if (advantageAck.durable_status !== 'ROLL_RECORDED') throw new Error('Advantage dice were not durably acknowledged.');
const advantageCommit = await dm.next(message => message.type === 'turn_committed' && message.transaction.declaration.includes("Soren's help"));
if (!advantageCommit.transaction.transaction_hash) throw new Error('Advantage check did not commit.');
screen.socket.send(JSON.stringify({type:'roll_submit', roll_id:advantageRoll.roll.id, mode:'physical', dice:[7,17],
  client_roll_submission_id:advantageSubmission}));
const rollReplay = await screen.next(message => message.type === 'roll_ack' && message.client_roll_submission_id === advantageSubmission && message.replayed);
if (rollReplay.roll_request_id !== advantageRoll.roll.id) throw new Error('Duplicate roll did not replay its durable receipt.');

const opposedID = crypto.randomUUID();
player.socket.send(JSON.stringify({type:'action_submit', client_action_id:opposedID, player_id:'renn', author:'Renn',
  text:'I race Lupin to the fern line.', visibility:'public'}));
await player.next(message => message.type === 'action_ack' && message.client_action_id === opposedID);
const opposedRoll = await screen.next(message => message.type === 'roll_requested' && message.roll?.opposed?.actor_id === 'lupin');
screen.socket.send(JSON.stringify({type:'roll_submit', roll_id:opposedRoll.roll.id, mode:'physical', dice:[14],
  client_roll_submission_id:crypto.randomUUID()}));
await dm.next(message => message.type === 'turn_committed' && message.transaction.declaration.includes('race Lupin'));

const secretID = crypto.randomUUID();
player.socket.send(JSON.stringify({type:'action_submit', client_action_id:secretID, player_id:'renn', author:'Renn',
  text:'I investigate to tell whether the watcher is concealing hostile intent.', visibility:'private'}));
await player.next(message => message.type === 'action_ack' && message.client_action_id === secretID);
const secretRoll = await dm.next(message => message.type === 'roll_requested' && message.roll?.secret === true);
if (!secretRoll.roll.ruling_locked_at) throw new Error('Secret roll was not locked before host resolution.');
await dm.next(message => message.type === 'turn_committed' && message.transaction.declaration.includes('watcher is concealing'));
const secretSnapshot = await screen.next(message => message.type === 'session_snapshot' && message.pending_roll == null);
if (secretSnapshot.last_result?.secret) throw new Error('Secret roll evidence leaked to the shared-screen snapshot.');

for (const connection of [dm, screen, player]) connection.socket.close();
console.log('Hands-off durable actions, transparent advantage, opposed checks, secret-roll privacy, automatic Contract 1.1 commits, and idempotent replay passed.');
