import assert from 'node:assert/strict';
import {cp, mkdtemp, readFile, rm} from 'node:fs/promises';
import {createServer} from 'node:http';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {WebSocket} from 'ws';
import {PLAY_MODES, normalizeSessionRuntime, runtimeProjection, updatePlayMode} from './session-runtime.mjs';
import {presentationRecipient, presentationRoute} from './presentation-router.mjs';

const normalized = normalizeSessionRuntime({play_mode:'invalid'});
assert.equal(normalized.play_mode, PLAY_MODES.IPHONE_SHARED_IPAD);
assert.equal(runtimeProjection(normalized, {connectedWayfolios:1, connectedScreens:0}).ready_to_play, true);
assert.equal(runtimeProjection(normalized, {connectedWayfolios:1, connectedScreens:0}).selected_mode_ready, false);
assert.equal(runtimeProjection(updatePlayMode(normalized, PLAY_MODES.IPHONE_ONLY),
  {connectedWayfolios:1, connectedScreens:0}).selected_mode_ready, true);
assert.equal(presentationRecipient(updatePlayMode(normalized, PLAY_MODES.IPHONE_ONLY),
  {kind:'shared'}, {role:'wayfolio', playerID:'renn'}), true);
assert.equal(presentationRecipient(updatePlayMode(normalized, PLAY_MODES.IPHONE_ONLY),
  {kind:'shared'}, {role:'screen'}), false);
assert.equal(presentationRecipient(normalized, {kind:'shared'}, {role:'screen'}), true);
assert.equal(presentationRecipient(normalized, {kind:'shared'}, {role:'wayfolio', playerID:'renn'}), false);
assert.equal(presentationRecipient(normalized, {kind:'wayfolios'}, {role:'wayfolio', playerID:'renn'}), true);
assert.equal(presentationRecipient(normalized, {kind:'wayfolios'}, {role:'screen'}), false);
assert.equal(presentationRecipient(normalized, {kind:'player', player_id:'renn'},
  {role:'wayfolio', playerID:'yugen'}), false);
assert.deepEqual(presentationRoute(updatePlayMode(normalized, PLAY_MODES.IPHONE_ONLY)),
  {public_display:'wayfolio', personal_display:'wayfolio', shared_ipad:'none'});

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
    const next = (predicate, timeout = 10_000) => {
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
      await next(message => message.type === 'joined');
      resolve({socket, next, messages});
    });
  });
}

async function startHost(port, data, campaign) {
  const child = spawn(process.execPath, ['server.mjs'], {cwd:new URL('.', import.meta.url), env:{...process.env,
    PORT:String(port), WAYFOLIO_DATA_DIRECTORY:data, WAYFOLIO_CAMPAIGN_PATH:campaign,
    OPENAI_API_KEY:''}, stdio:['ignore','pipe','pipe']});
  child.stderr.on('data', chunk => process.stderr.write(`[session-mode host] ${chunk}`));
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

const temporary = await mkdtemp(join(tmpdir(), 'wayfolio-session-mode-'));
const campaign = join(temporary, 'campaign'); const data = join(temporary, 'data');
await cp(new URL('../Campaigns/HemlockDevelopment/', import.meta.url), campaign, {recursive:true});
const probe = createServer(); const port = await listen(probe); await new Promise(resolve => probe.close(resolve));
let host;
try {
  host = await startHost(port, data, campaign);
  let dm = await connect(port, 'dm');
  let renn = await connect(port, 'wayfolio', {player_id:'renn', player_name:'Renn Hazel', character_id:'renn', device_id:'mode-renn'});
  let state = await renn.next(message => message.type === 'session_snapshot');
  assert.equal(state.session_runtime.play_mode, PLAY_MODES.IPHONE_SHARED_IPAD);
  assert.equal(state.session_runtime.ready_to_play, true);
  assert.equal(state.session_runtime.selected_mode_ready, false);

  renn.socket.send(JSON.stringify({type:'session_mode_set', play_mode:PLAY_MODES.IPHONE_ONLY}));
  state = await renn.next(message => message.type === 'session_mode_changed');
  assert.equal(state.session_runtime.play_mode, PLAY_MODES.IPHONE_ONLY);
  assert.equal(state.session_runtime.selected_mode_ready, true);
  dm.socket.send(JSON.stringify({type:'dm_presentation', event:{
    type:'dialogue', line_id:'phone-only-routing', speaker_id:'narrator',
    text:'The Wayfolio carries the shared scene.', performance:'measured',
  }}));
  const phonePresentation = await renn.next(message => message.type === 'presentation_event'
    && message.event?.line_id === 'phone-only-routing');
  assert.equal(phonePresentation.audience.kind, 'shared');

  // In phone-only mode the assigned Wayfolio is both the personal controller
  // and the public presentation surface, so it must be able to complete its own
  // requested roll. Another phone must never be able to submit that roll.
  const yugen = await connect(port, 'wayfolio', {player_id:'yugen', player_name:'Yūgen', character_id:'yugen', device_id:'mode-yugen'});
  dm.socket.send(JSON.stringify({type:'dm_start_encounter'}));
  const prompt = await renn.next(message => message.type === 'private_prompt');
  renn.socket.send(JSON.stringify({type:'action_submit', prompt_id:prompt.prompt_id,
    player_id:'renn', author:'Renn', visibility:'public', client_action_id:'phone-roll-action',
    text:'I study the blue motes without touching them.'}));
  const phoneRoll = await renn.next(message => message.type === 'roll_requested');
  assert.equal(phoneRoll.roll.playerID, 'renn');
  yugen.socket.send(JSON.stringify({type:'roll_submit', roll_id:phoneRoll.roll.id,
    mode:'digital', client_roll_submission_id:'wrong-phone-roll'}));
  const deniedRoll = await yugen.next(message => message.type === 'error');
  assert.match(deniedRoll.message, /active presentation device/i);
  renn.socket.send(JSON.stringify({type:'roll_submit', roll_id:phoneRoll.roll.id,
    mode:'digital', client_roll_submission_id:'phone-only-roll'}));
  const acceptedRoll = await renn.next(message => message.type === 'roll_ack');
  assert.equal(acceptedRoll.durable_status, 'ROLL_RECORDED');
  await renn.next(message => message.type === 'private_result');
  yugen.socket.close();

  dm.socket.send(JSON.stringify({type:'dm_open_play_start'}));
  await dm.next(message => ['open_play_started','journey_started','journey_continued'].includes(message.type));
  state = await dm.next(message => message.type === 'session_snapshot' && message.journey_live === true);
  const checkpoint = state.story_state.checkpoint;

  renn.socket.send(JSON.stringify({type:'session_mode_set', play_mode:PLAY_MODES.IPHONE_SHARED_IPAD}));
  await renn.next(message => message.type === 'session_mode_changed'
    && message.session_runtime.play_mode === PLAY_MODES.IPHONE_SHARED_IPAD);
  let screen = await connect(port, 'screen', {device_id:'shared-ipad-one'});
  state = await screen.next(message => message.type === 'session_snapshot' && message.session_runtime.shared_ipad_connected);
  assert.equal(state.session_runtime.selected_mode_ready, true);
  assert.deepEqual(state.presentation_route,
    {public_display:'shared_ipad', personal_display:'wayfolio', shared_ipad:'optional'});
  dm.socket.send(JSON.stringify({type:'dm_presentation', event:{
    type:'dialogue', line_id:'shared-ipad-routing', speaker_id:'narrator',
    text:'The shared display carries the public scene.', performance:'measured',
  }}));
  await screen.next(message => message.type === 'presentation_event'
    && message.event?.line_id === 'shared-ipad-routing');
  await assert.rejects(renn.next(message => message.type === 'presentation_event'
    && message.event?.line_id === 'shared-ipad-routing', 300));
  dm.socket.send(JSON.stringify({type:'dm_presentation', event:{
    type:'dialogue', line_id:'paired-wayfolio-routing', speaker_id:'wayfolio',
    text:'Your Wayfolio has recorded the change.', performance:'warm, concise',
  }}));
  const phoneCommentary = await renn.next(message => message.type === 'presentation_event'
    && message.event?.line_id === 'paired-wayfolio-routing');
  assert.equal(phoneCommentary.audience.kind, 'wayfolios');
  assert.equal(phoneCommentary.event.voice_profile_id, 'wayfolio');
  await assert.rejects(screen.next(message => message.type === 'presentation_event'
    && message.event?.line_id === 'paired-wayfolio-routing', 300));

  screen.socket.close();
  state = await renn.next(message => message.type === 'session_snapshot'
    && message.session_runtime.shared_ipad_connected === false
    && message.session_runtime.play_mode === PLAY_MODES.IPHONE_SHARED_IPAD
    && message.story_state?.checkpoint === checkpoint);
  assert.equal(state.session_runtime.play_mode, PLAY_MODES.IPHONE_SHARED_IPAD);
  assert.equal(state.session_runtime.ready_to_play, true);
  assert.equal(state.scene_title.length > 0, true);
  assert.equal(state.story_state.checkpoint, checkpoint);

  dm.socket.close(); renn.socket.close();
  await stopHost(host); host = null;
  const saved = JSON.parse(await readFile(join(data, 'campaign-state.json'), 'utf8'));
  assert.equal(saved.sessionRuntime.play_mode, PLAY_MODES.IPHONE_SHARED_IPAD);
  assert.equal(saved.journeyLive, true);
  assert.equal(saved.story.checkpoint, checkpoint);

  host = await startHost(port, data, campaign);
  dm = await connect(port, 'dm');
  renn = await connect(port, 'wayfolio', {player_id:'renn', player_name:'Renn Hazel', character_id:'renn', device_id:'mode-renn'});
  state = await dm.next(message => message.type === 'session_snapshot');
  assert.equal(state.session_runtime.play_mode, PLAY_MODES.IPHONE_SHARED_IPAD);
  assert.equal(state.session_runtime.shared_ipad_connected, false);
  assert.equal(state.journey_live, true);
  assert.equal(state.story_state.checkpoint, checkpoint);
  assert.equal(state.voice_assignments.assignments.some(item =>
    item.speaker_id === 'wayfolio' && item.voice_profile_id === 'wayfolio'), true);
  screen = await connect(port, 'screen', {device_id:'shared-ipad-one'});
  state = await screen.next(message => message.type === 'session_snapshot' && message.session_runtime.shared_ipad_connected);
  assert.equal(state.session_runtime.selected_mode_ready, true);

  for (const connection of [dm, renn, screen]) connection.socket.close();
  console.log('Session modes, detachable shared iPad, and restart continuity passed.');
} finally {
  if (host) await stopHost(host);
  await rm(temporary, {recursive:true, force:true});
}
