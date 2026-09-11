import {WebSocket} from 'ws';

if (process.env.WAYFOLIO_ALLOW_LEGACY_EXTERNAL_TEST !== '1' || !process.env.HOST_PORT) {
  throw new Error(
    'Legacy external-host test blocked. It can modify campaign data. Use npm test for the isolated suite.'
  );
}

const port = Number(process.env.HOST_PORT || 8787);
const baseURL = `http://localhost:${port}`;
let wayfolioResumeToken = '';
const phase = value => console.log(`[Wayfolio test] ${value}`);

class Inbox {
  constructor(socket, name) {
    this.name = name;
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
        const waiting = this.messages.slice(-12).map(message => `${message.type}:${message.event?.line_id || message.story_state?.checkpoint || ''}`).join(', ');
        reject(new Error(`${this.name} timed out waiting for a session message. Recent unmatched messages: ${waiting || 'none'}`));
      }, timeout);
    });
  }
}

async function open(role, player = false) {
  const socket = new WebSocket(`ws://localhost:${port}/session`);
  const inbox = new Inbox(socket, player ? 'Renn' : role);
  await new Promise((resolve, reject) => {
    socket.once('open', resolve);
    socket.once('error', reject);
  });
  socket.send(JSON.stringify({
    type:'join', role, session_code:'HEMLOCK',
    ...(player ? {player_id:'renn', player_name:'Renn', character_id:'renn',
      device_id:'wayfolio-integration-test-device', ...(wayfolioResumeToken ? {resume_token:wayfolioResumeToken} : {})} : {}),
  }));
  const joined = await inbox.next(message => message.type === 'joined');
  if (player) wayfolioResumeToken = joined.resume_token;
  return {socket, inbox};
}

const dm = await open('dm');
phase('DM joined');
const screen = await open('screen');
phase('shared screen joined');
let renn = await open('wayfolio', true);
phase('Renn joined');
const initialResumeToken = wayfolioResumeToken;
renn = await open('wayfolio', true);
phase('Renn reconnected');
if (!initialResumeToken || wayfolioResumeToken !== initialResumeToken) {
  throw new Error('The assigned Wayfolio did not preserve its resume identity.');
}
const rejoinedSnapshot = await dm.inbox.next(message => message.type === 'session_snapshot' &&
  message.players?.some(player => player.id === 'renn' && player.connected));
phase('reconnection snapshot verified');
const publicRenn = rejoinedSnapshot.players.find(player => player.id === 'renn');
if (publicRenn.resume_token || publicRenn.device_id) {
  throw new Error('Private Wayfolio identity material leaked into the table roster.');
}

screen.socket.send(JSON.stringify({type:'action_submit', player_id:'table', author:'At the table',
  text:'This should not become a private shared-screen response.', visibility:'private'}));
const sharedPrivateRejected = await screen.inbox.next(message =>
  message.type === 'error' && message.message.includes('individual Wayfolio')
);
if (!sharedPrivateRejected) throw new Error('The shared screen accepted a private player response.');
phase('privacy boundary verified');

const catalogResponse = await fetch(`${baseURL}/audio-catalog.json`);
const voicesResponse = await fetch(`${baseURL}/character-voice-profiles.json`);
const locationsResponse = await fetch(`${baseURL}/location-ambience-profiles.json`);
const visualProfilesResponse = await fetch(`${baseURL}/assets/approved/characters/visual-profiles.json`);
const rennPortraitResponse = await fetch(`${baseURL}/assets/approved/characters/renn-hazel.jpeg`);
const audioResponse = await fetch(`${baseURL}/Audio/SFX/Creature/Form/slime_curious_move.wav`);
if (!catalogResponse.ok || !(await catalogResponse.json()).cues?.length) throw new Error('Audio catalog route failed.');
const voices = await voicesResponse.json();
if (!voicesResponse.ok || voices.default_profile !== 'narrator' || !voices.profiles?.renn ||
    !voices.profiles?.koori || !voices.profiles?.soren || !voices.profiles?.lupin) {
  throw new Error('Character voice registry route failed.');
}
const locations = await locationsResponse.json();
if (!locationsResponse.ok || !locations.profiles?.tavern_busy || !locations.profiles?.river_calm) {
  throw new Error('Location ambience profiles route failed.');
}
const visualProfiles = await visualProfilesResponse.json();
if (!visualProfilesResponse.ok || !visualProfiles.profiles?.renn?.portrait) {
  throw new Error('Approved character visual profiles route failed.');
}
if (!rennPortraitResponse.ok || (await rennPortraitResponse.arrayBuffer()).byteLength < 1000) {
  throw new Error('Renn dialogue portrait route failed.');
}
if (!audioResponse.ok || (await audioResponse.arrayBuffer()).byteLength < 1000) throw new Error('Audio asset route failed.');
phase('content routes verified');

dm.socket.send(JSON.stringify({type:'dm_presentation', event:{
  type:'dialogue', line_id:'voice-registry-test', speaker_id:'koori',
  text:'The lanterns are waking up.', performance:'joyful',
  priority:'normal', interrupt:'queue', caption:true,
}}));
const dialogueEvent = await screen.inbox.next(message =>
  message.type === 'presentation_event' && message.event.line_id === 'voice-registry-test'
);
if (dialogueEvent.event.speaker_id !== 'koori') throw new Error('Speaker identity was not preserved.');
phase('dialogue routing verified');

dm.socket.send(JSON.stringify({type:'dm_presentation', event:{
  type:'ambience_scene', action:'play', profile:'tavern_busy', volume:0.4,
}}));
await screen.inbox.next(message => message.type === 'presentation_event' && message.event.type === 'ambience_scene');
const ambienceReconnect = await open('screen');
const ambienceRestored = await ambienceReconnect.inbox.next(message => message.type === 'session_snapshot');
if (ambienceRestored.presentation_state?.ambience?.profile !== 'tavern_busy') {
  throw new Error('Layered location ambience was not restored after reconnect.');
}
ambienceReconnect.socket.close();

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
phase('dice modes verified');

const storyStartedAt = Date.now();
dm.socket.send(JSON.stringify({type:'dm_start_encounter'}));
phase('story start requested');
const openingSpeakers = new Set();
while (openingSpeakers.size < 3) {
  const line = await screen.inbox.next(message =>
    message.type === 'presentation_event' && message.event.type === 'dialogue' &&
    message.event.line_id?.startsWith('motes-opening')
  );
  openingSpeakers.add(line.event.speaker_id);
}
if (![...['narrator','soren','lupin']].every(speaker => openingSpeakers.has(speaker))) {
  throw new Error('The playable opening did not include narrator, Soren, and Lupin.');
}
const encounterPrompt = await renn.inbox.next(message =>
  message.type === 'private_prompt' && message.title.includes('Renn')
);
if (!encounterPrompt.allows_freeform || encounterPrompt.choices.length !== 0) {
  throw new Error('The playable chapter still requires canned choices.');
}
renn.socket.send(JSON.stringify({
  type:'action_submit', player_id:'renn', author:'Renn', prompt_id:encounterPrompt.prompt_id,
  text:'I study the motes from a distance without touching them.', visibility:'private',
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
if (rennSnapshot.character?.equipment?.length !== 4 || !rennSnapshot.character_state?.inventory?.some(item => item.includes("cook's utensils"))) {
  throw new Error('Renn’s canonical equipment and carried inventory were not delivered.');
}
const publicSnapshot = await screen.inbox.next(message =>
  message.type === 'session_snapshot' && message.last_result?.choice?.includes('study the motes') &&
  Date.parse(message.last_result.at) >= storyStartedAt
);
if (publicSnapshot.character || publicSnapshot.character_state) {
  throw new Error('Private Wayfolio character data leaked onto the shared screen.');
}
if (publicSnapshot.story_state?.checkpoint !== 'crown_hare_response' ||
    publicSnapshot.story_state?.creature?.name !== 'Crown Hare') {
  throw new Error('The Crown Hare encounter was not checkpointed after the story roll.');
}
const crownHarePrompt = await renn.inbox.next(message =>
  message.type === 'private_prompt' && message.title.includes('Crown Hare')
);
renn.socket.send(JSON.stringify({type:'action_submit', player_id:'renn', author:'Renn',
  prompt_id:crownHarePrompt.prompt_id, text:'I kneel and offer my open hand while Soren and Lupin watch.', visibility:'public'}));
const crownHareRoll = await screen.inbox.next(message =>
  message.type === 'roll_requested' && message.roll.storyBeat === 'crown_hare_action'
);
screen.socket.send(JSON.stringify({type:'roll_submit', roll_id:crownHareRoll.roll.id, mode:'physical', die:20}));
await renn.inbox.next(message => message.type === 'private_result' && message.detail.includes('invitation'));
const completedChapter = await screen.inbox.next(message =>
  message.type === 'session_snapshot' && message.story_state?.checkpoint === 'root_door_found'
);
if (completedChapter.story_state.stage !== 'chapter_complete') {
  throw new Error('The story did not advance beyond the Crown Hare engagement.');
}
phase('scripted bridge chapter verified');

dm.socket.send(JSON.stringify({type:'dm_start_encounter'}));
await renn.inbox.next(message => message.type === 'private_prompt' && message.allows_freeform);
phase('shared-device action bridge restarted');
screen.socket.send(JSON.stringify({type:'action_submit', player_id:'table', author:'At the table',
  text:'I walk carefully toward the motes.', visibility:'public'}));
const sharedActionRoll = await screen.inbox.next(message =>
  message.type === 'roll_requested' && message.roll.choice.includes('walk carefully')
);
if (sharedActionRoll.roll.playerID !== 'renn') {
  throw new Error('A shared-device story action was not assigned to Renn.');
}
screen.socket.send(JSON.stringify({type:'roll_submit', roll_id:sharedActionRoll.roll.id, mode:'physical', die:12}));
await renn.inbox.next(message => message.type === 'private_result');
phase('shared-device action verified');

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
phase('private action routing verified');

renn.socket.send(JSON.stringify({type:'action_submit', player_id:'renn', author:'Renn',
  text:'I call everyone toward the bridge.', visibility:'public'}));
await Promise.all([
  dm.inbox.next(message => message.type === 'action_event' && message.text.includes('everyone')),
  screen.inbox.next(message => message.type === 'action_event' && message.text.includes('everyone')),
]);
phase('public action routing verified');

dm.socket.send(JSON.stringify({type:'dm_open_play_start'}));
await dm.inbox.next(message => message.type === 'session_snapshot' && message.open_play_active === true);
phase('open play started');
renn.socket.send(JSON.stringify({type:'action_submit', player_id:'renn', author:'Renn',
  text:'I ask Soren what she notices about the motes, then listen without interrupting.', visibility:'public'}));
const review = await dm.inbox.next(message => message.type === 'review_proposal');
phase('open-play ruling proposed');
if (review.proposal.declaration !== 'I ask Soren what she notices about the motes, then listen without interrupting.' ||
    !review.proposal.declaration_hash || !review.proposal.context.present.includes('soren')) {
  throw new Error('Open-play review did not preserve the exact declaration and Hemlock context.');
}
dm.socket.send(JSON.stringify({type:'dm_review_ruling', proposal_id:review.proposal.id, action:'approve',
  interpretation:{...review.proposal.interpretation, skill:'Insight', dc:10, requires_roll:true}}));
const reviewedRoll = await screen.inbox.next(message =>
  message.type === 'roll_requested' && message.roll.proposalID === review.proposal.id
);
screen.socket.send(JSON.stringify({type:'roll_submit', roll_id:reviewedRoll.roll.id, mode:'physical', die:12}));
await renn.inbox.next(message => message.type === 'private_result' && message.detail.includes('Insight'));
const consequence = await dm.inbox.next(message => message.type === 'consequence_proposal');
if (consequence.consequence.declaration !== review.proposal.declaration ||
    consequence.consequence.prior_state_head !== review.proposal.context.state_head ||
    consequence.consequence.companion_lines?.map(line => line.speaker_id).join(',') !== 'soren,lupin' ||
    !consequence.consequence.adjudication_source) {
  throw new Error('The consequence proposal lost declaration or prior-head authority.');
}
dm.socket.send(JSON.stringify({type:'dm_commit_consequence', consequence_id:consequence.consequence.id,
  consequence:{public_narration:'Soren studies the motes with Renn while Lupin watches the bridge approach.',
    private_information:'Renn notices that the motes respond to Soren’s voice.', elapsed_minutes:4}}));
const committed = await dm.inbox.next(message => message.type === 'turn_committed');
if (committed.transaction.declaration !== review.proposal.declaration ||
    committed.transaction.previous_transaction_hash !== consequence.consequence.previous_transaction_hash ||
    !committed.transaction.transaction_hash) {
  throw new Error('The open-play transaction chain is incomplete.');
}
const companionPresentation = await screen.inbox.next(message => message.type === 'presentation_event' &&
  message.event.line_id?.startsWith(`${review.proposal.id}-companion-`));
if (!['soren','lupin'].includes(companionPresentation.event.speaker_id)) {
  throw new Error('Committed companion reaction was not routed to the approved voice.');
}
const committedSnapshot = await dm.inbox.next(message => message.type === 'session_snapshot' &&
  message.world_state?.state_head === committed.transaction.resulting_state_head);
if (!committedSnapshot.transactions?.length || committedSnapshot.world_state.time.elapsed_minutes < 4) {
  throw new Error('Committed consequence did not atomically update world state and history.');
}
dm.socket.send(JSON.stringify({type:'dm_undo_open_play'}));
const undoBlocked = await dm.inbox.next(message => message.type === 'error' && message.message.includes('cannot be silently undone'));
if (!undoBlocked.message.includes('correction transaction')) {
  throw new Error('Formal history did not explain the correction requirement.');
}

for (const connection of [dm, screen, renn]) connection.socket.close();
console.log('Audio, dice, open-play review, formal atomic commit, persistence, and history protection passed.');
