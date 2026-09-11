import {mkdtemp} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {WebSocket} from 'ws';

const directory = await mkdtemp(join(tmpdir(), 'wayfolio-party-state-'));
const port = 8981;
const server = spawn(process.execPath, ['server.mjs'], {cwd:new URL('.', import.meta.url), env:{...process.env,
  PORT:String(port), WAYFOLIO_DATA_DIRECTORY:directory, WAYFOLIO_SESSION_STATE_PATH:join(directory, 'state.json'),
  WAYFOLIO_CAMPAIGN_REGISTRY_PATH:join(directory, 'campaign-registry.json')}});

async function joinRole(role, extra = {}) {
  const socket = new WebSocket(`ws://127.0.0.1:${port}/session`);
  const messages = [];
  socket.on('message', raw => messages.push(JSON.parse(raw)));
  await new Promise((resolve, reject) => { socket.once('open', resolve); socket.once('error', reject); });
  socket.send(JSON.stringify({type:'join', role, session_code:'HEMLOCK', ...extra}));
  const deadline = Date.now() + 3000;
  while (!messages.some(value => ['joined', 'error'].includes(value.type)) && Date.now() < deadline) {
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  return {socket, messages};
}

try {
  await new Promise((resolve, reject) => {
    const timer = setTimeout(resolve, 650);
    server.once('exit', code => { clearTimeout(timer); reject(new Error(`Host exited before lifecycle integration testing (${code}).`)); });
  });
  const info = await fetch(`http://127.0.0.1:${port}/session-info.json`).then(response => response.json());
  if (info.characters.length !== 1 || info.characters[0].id !== 'renn') {
    throw new Error('NPC-controlled characters leaked into the Wayfolio character selector.');
  }

  const rejectedContext = await fetch(`http://127.0.0.1:${port}/api/shared-login-context?code=WRONG`);
  if (rejectedContext.status !== 403) throw new Error('The public login projection accepted an invalid journey code.');
  const loginContext = await fetch(`http://127.0.0.1:${port}/api/shared-login-context?code=HEMLOCK`).then(response => response.json());
  if (loginContext.schema_version !== 2 || loginContext.party.length !== 3
      || loginContext.party.some(value => !['renn', 'soren', 'lupin'].includes(value.id))) {
    throw new Error('The public login projection did not contain exactly the introduced party.');
  }
  if (!loginContext.story_checkpoint || !loginContext.session_information || !loginContext.current_location
      || loginContext.sync_indicators?.length !== 5 || loginContext.ready_to_begin !== true) {
    throw new Error('The Spiritbloom pre-session readiness contract was incomplete.');
  }
  const rennLogin = loginContext.party.find(value => value.id === 'renn');
  if (rennLogin.sprite?.approval_status !== 'approved' || rennLogin.sprite?.login_eligible !== true) {
    throw new Error('Renn did not receive the approved login sprite contract.');
  }
  if (loginContext.party.some(value => value.sprite
      && !['approved'].includes(value.sprite.approval_status))) {
    throw new Error('The login projection substituted unapproved character art.');
  }
  if ('character_lifecycle' in loginContext || 'asset_diagnostics' in loginContext) {
    throw new Error('Private party or asset state leaked through the login projection.');
  }

  const soren = await joinRole('wayfolio', {player_id:'soren', player_name:'Soren', character_id:'soren', device_id:'soren-test'});
  if (!soren.messages.some(value => value.type === 'error' && value.message.includes('available Wayfolio character'))) {
    throw new Error('An NPC-controlled character was allowed to claim a player Wayfolio.');
  }

  const dm = await joinRole('dm');
  await new Promise(resolve => setTimeout(resolve, 80));
  const dmState = dm.messages.find(value => value.type === 'session_snapshot');
  if (!dmState?.character_lifecycle?.renn || !dmState?.character_lifecycle?.soren || !dmState?.asset_diagnostics?.length) {
    throw new Error('Private lifecycle or asset diagnostics were missing from the DM host.');
  }
  const validFirstSync = (dmState?.campaign_registry_status?.sync_status === 'READY_FOR_FIRST_SYNC'
      && dmState?.first_shared_state_reconciliation?.can_cut_over === false)
    || (dmState?.campaign_registry_status?.sync_status === 'SYNCED'
      && dmState?.campaign_registry_status?.cutover_complete === true);
  if (!validFirstSync) {
    throw new Error('The DM host did not receive the controlled first-sync status.');
  }

  const screen = await joinRole('screen');
  await new Promise(resolve => setTimeout(resolve, 80));
  const screenState = screen.messages.find(value => value.type === 'session_snapshot');
  if ('character_lifecycle' in screenState || 'asset_diagnostics' in screenState) {
    throw new Error('Private lifecycle or asset diagnostics leaked to the shared screen.');
  }
  if (screenState.campaign_registry?.characters || screenState.campaign_registry?.change_log) {
    throw new Error('Private campaign registry state leaked to the shared screen.');
  }
  if (!screenState.public_party_roster.some(value => value.id === 'soren')
      || !screenState.public_party_roster.some(value => value.id === 'lupin')) {
    throw new Error('Introduced NPC companions were omitted from the public party roster.');
  }
  for (const connection of [soren, dm, screen]) connection.socket.close();
  console.log('WF-049 lifecycle, Wayfolio selection, reveal, and private diagnostic integration passed.');
} finally {
  server.kill('SIGTERM');
}
