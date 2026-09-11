import {mkdtemp} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {WebSocket} from 'ws';

const directory = await mkdtemp(join(tmpdir(), 'wayfolio-two-player-'));
const port = 8992;
const server = spawn(process.execPath, ['server.mjs'], {cwd:new URL('.', import.meta.url), env:{...process.env,
  PORT:String(port), WAYFOLIO_DATA_DIRECTORY:directory, WAYFOLIO_SESSION_STATE_PATH:join(directory, 'state.json')}});

async function waitFor(messages, predicate, label) {
  const deadline = Date.now() + 3500;
  while (Date.now() < deadline) {
    const match = messages.find(predicate);
    if (match) return match;
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  throw new Error(`Timed out waiting for ${label}.`);
}

async function joinRole(role, extra = {}) {
  const socket = new WebSocket(`ws://127.0.0.1:${port}/session`);
  const messages = [];
  socket.on('message', raw => messages.push(JSON.parse(raw)));
  await new Promise((resolve, reject) => { socket.once('open', resolve); socket.once('error', reject); });
  socket.send(JSON.stringify({type:'join', role, session_code:'HEMLOCK', ...extra}));
  await waitFor(messages, value => ['joined', 'error'].includes(value.type), `${role} join`);
  return {socket, messages};
}

try {
  await new Promise((resolve, reject) => {
    const timer = setTimeout(resolve, 650);
    server.once('exit', code => { clearTimeout(timer); reject(new Error(`Host exited before two-player testing (${code}).`)); });
  });

  const info = await fetch(`http://127.0.0.1:${port}/session-info.json`).then(response => response.json());
  if (info.characters.some(value => ['yugen', 'hinosuke'].includes(value.id))) {
    throw new Error('A not-yet-introduced player or companion leaked through public session information.');
  }

  const renn = await joinRole('wayfolio', {player_id:'renn', player_name:'Renn', character_id:'renn', device_id:'renn-phone'});
  const yugen = await joinRole('wayfolio', {player_id:'yugen', player_name:'Yūgen', character_id:'yugen', device_id:'yugen-phone'});
  const yugenSnapshot = await waitFor(yugen.messages, value => value.type === 'session_snapshot' && value.character?.id === 'yugen', 'Yūgen private state');
  if (yugenSnapshot.character.hp.current !== 10 || yugenSnapshot.character.armor_class !== 13) {
    throw new Error('Yūgen did not receive his own mechanics on his private Wayfolio.');
  }
  if (!yugenSnapshot.character.companions?.some(value => value.name === 'Hinosuke')
      || !yugenSnapshot.campaign_knowledge?.companions?.some(value => value.name === 'Hinosuke')) {
    throw new Error('Hinosuke was not attached to Yūgen’s private Wayfolio state.');
  }
  if (yugenSnapshot.character_catalog.some(value => value.id === 'hinosuke')) {
    throw new Error('Hinosuke was incorrectly offered as a playable Wayfolio character.');
  }

  const screen = await joinRole('screen');
  let screenSnapshot = await waitFor(screen.messages, value => value.type === 'session_snapshot', 'initial shared snapshot');
  if (screenSnapshot.public_party_roster.some(value => ['yugen', 'hinosuke'].includes(value.id))) {
    throw new Error('Yūgen or Hinosuke appeared publicly before the DM introduced them.');
  }

  const dm = await joinRole('dm');
  const dmSnapshot = await waitFor(dm.messages, value => value.type === 'session_snapshot', 'DM snapshot');
  if (!dmSnapshot.character_catalog.some(value => value.id === 'yugen')) {
    throw new Error('The private DM host could not see Yūgen as an available player character.');
  }
  dm.socket.send(JSON.stringify({type:'dm_introduce_party_member', character_id:'yugen'}));
  await waitFor(dm.messages, value => value.type === 'party_member_introduced' && value.character_id === 'yugen', 'Yūgen introduction');
  screenSnapshot = await waitFor(screen.messages, value => value.type === 'session_snapshot'
    && value.public_party_roster.some(member => member.id === 'yugen'), 'public Yūgen reveal');
  if (!screenSnapshot.public_party_roster.some(value => value.id === 'hinosuke')) {
    throw new Error('Hinosuke did not enter public party state with Yūgen.');
  }
  if (screenSnapshot.character_catalog.some(value => value.id === 'hinosuke')) {
    throw new Error('The companion appeared in the shared player-character selector.');
  }

  for (const connection of [renn, yugen, screen, dm]) connection.socket.close();
  console.log('Two-player Renn/Yūgen assignment, Hinosuke attachment, and reveal privacy passed.');
} finally {
  server.kill('SIGTERM');
}
