import assert from 'node:assert/strict';
import {cp, mkdtemp, rm} from 'node:fs/promises';
import {createServer} from 'node:http';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {WebSocket} from 'ws';

const temporary = await mkdtemp(join(tmpdir(), 'wayfolio-item-use-'));
const campaign = join(temporary, 'campaign');
const data = join(temporary, 'data');
await cp(new URL('../Campaigns/HemlockDevelopment/', import.meta.url), campaign, {recursive:true});

const probe = createServer();
const port = await new Promise((resolve, reject) => {
  probe.once('error', reject);
  probe.listen(0, '127.0.0.1', () => resolve(probe.address().port));
});
await new Promise(resolve => probe.close(resolve));

const host = spawn(process.execPath, ['server.mjs'], {cwd:new URL('.', import.meta.url), env:{...process.env,
  PORT:String(port), WAYFOLIO_DATA_DIRECTORY:data, WAYFOLIO_CAMPAIGN_PATH:campaign, OPENAI_API_KEY:''},
  stdio:['ignore', 'pipe', 'pipe']});
await new Promise((resolve, reject) => {
  let output = '';
  const timer = setTimeout(() => reject(new Error(`Host did not start. ${output}`)), 15_000);
  host.stdout.on('data', chunk => { output += chunk; if (output.includes('Wayfolio host:')) { clearTimeout(timer); resolve(); } });
  host.stderr.on('data', chunk => { output += chunk; });
  host.once('exit', code => reject(new Error(`Host exited ${code}. ${output}`)));
});

const socket = new WebSocket(`ws://127.0.0.1:${port}/session`);
const messages = [];
const waiters = [];
socket.on('message', raw => {
  const message = JSON.parse(raw);
  const index = waiters.findIndex(waiter => waiter.predicate(message));
  if (index >= 0) waiters.splice(index, 1)[0].resolve(message); else messages.push(message);
});
const next = (predicate, timeout = 10_000) => {
  const index = messages.findIndex(predicate);
  if (index >= 0) return Promise.resolve(messages.splice(index, 1)[0]);
  return new Promise((resolve, reject) => {
    const waiter = {predicate, resolve}; waiters.push(waiter);
    setTimeout(() => reject(new Error('Timed out waiting for item-use protocol message.')), timeout).unref?.();
  });
};

try {
  await new Promise((resolve, reject) => { socket.once('open', resolve); socket.once('error', reject); });
  socket.send(JSON.stringify({type:'join', role:'wayfolio', session_code:'HEMLOCK', player_id:'renn',
    player_name:'Renn Hazel', character_id:'renn', device_id:'item-use-test'}));
  await next(message => message.type === 'joined');
  const snapshot = await next(message => message.type === 'session_snapshot');
  const itemName = 'Potion of Healing brewed by Renn';
  assert.equal(snapshot.character_state.inventory.filter(item => item === itemName).length, 1);
  const request = {type:'item_use', client_item_use_id:'durable-item-use-one', player_id:'renn',
    item_id:'potion-of-healing-brewed-by-renn', item_name:itemName, quantity:'1', requested_action:'consume'};
  socket.send(JSON.stringify(request));
  const accepted = await next(message => message.type === 'item_use_ack');
  assert.equal(accepted.character_state.inventory.includes(itemName), false);
  socket.send(JSON.stringify(request));
  const replay = await next(message => message.type === 'item_use_ack' && message.replayed === true);
  assert.equal(replay.character_state.inventory.includes(itemName), false);
  console.log('Structured item use validates, decrements once, refreshes state, and replays idempotently.');
} finally {
  socket.close();
  host.kill('SIGTERM');
  await new Promise(resolve => host.once('exit', resolve));
  await rm(temporary, {recursive:true, force:true});
}
