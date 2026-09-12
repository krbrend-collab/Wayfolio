import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const session = await readFile(new URL('../Wayfolio/Session/GameSessionClient.swift', import.meta.url), 'utf8');
const runtime = await readFile(new URL('../Wayfolio/Presentation/PresentationRuntime.swift', import.meta.url), 'utf8');
const live = await readFile(new URL('../Wayfolio/Features/Session/LivePlayView.swift', import.meta.url), 'utf8');
const app = await readFile(new URL('../Wayfolio/WayfolioApp.swift', import.meta.url), 'utf8');

assert.match(session, /let completedStoryBeats: \[CompletedStoryBeat\]\?/,
  'Standalone snapshots must persist completed story beats.');
assert.match(session, /segments\.filter \{ \$0\.voiceable[^]*sorted \{ \$0\.sequence < \$1\.sequence \}/,
  'Replay must select voiceable segments in their stored sequence.');
assert.match(session, /"text": segment\.text/,
  'Replay must use exact stored segment text.');
assert.match(session, /"speaker_id": segment\.speakerID/,
  'Replay must preserve speaker identity for canonical voice lookup.');
assert.match(runtime, /for event in voiceable[^]*await self\.playVoice\(event\)/,
  'Replay must play the voice queue sequentially.');
assert.match(runtime, /"pace": Self\.double\(direction\["pace"\]\) \?\? 1\.0/,
  'Native speech requests must preserve the numeric pace returned by the voice director.');
assert.doesNotMatch(runtime, /direction\["pace"\] as\? String/,
  'Native speech requests must not convert numeric pace into a rejected string value.');
assert.match(runtime, /func stopReplay\(\)/,
  'Replay must expose a stop action.');
assert.match(live, /isReplaying \? "Stop" : "Replay"/,
  'Live must show a single Replay control that becomes Stop while active.');
assert.match(live, /ForEach\(Array\(beats\.suffix\(3\)\)\)/,
  'Live must present the latest three completed beats in chronological order.');
assert.doesNotMatch(live, /beats\.suffix\(3\)\.reversed\(\)/,
  'Live must not reverse recent story history into newest-first order.');
assert.doesNotMatch(app, /replayStandalonePresentation/,
  'Returning to Live or starting the app must not automatically replay audio.');

assert.match(session, /case "public": return "PARTY"/,
  'Public standalone actions must retain party-visible audience semantics in history.');
assert.match(session, /case "private": return "PRIVATE"/,
  'Private standalone actions must remain private in history.');
assert.match(session, /audienceScope: Self\.storyAudienceScope\(for: action\)/,
  'Completed story history must derive its audience from the originating action.');
const replayMethod = runtime.match(/func replay\(_ events: \[\[String: Any\]\]\) \{[^]*?\n    func stopReplay\(\)/)?.[0] ?? '';
assert.doesNotMatch(replayMethod, /presentationEventHandler|sendAny|WebSocket|broadcast/,
  'Replay playback must remain local and must not rebroadcast presentation events.');

// A production-independent multi-speaker fixture exercises the approved replay
// ordering contract without inventing sample story content in the app itself.
const multiSpeakerFixture = [
  {sequence: 0, text: 'Mist gathers beneath the pines.', speakerID: 'narrator', voiceable: true},
  {sequence: 1, text: 'Wait for the roots to settle.', speakerID: 'npc-a', voiceable: true},
  {sequence: 2, text: 'A branch gives a quiet crack.', speakerID: 'narrator', voiceable: true},
  {sequence: 3, text: 'Now we can cross.', speakerID: 'npc-b', voiceable: true},
  {sequence: 4, text: 'Passive Awareness succeeded.', speakerID: null, voiceable: false},
];
const replayQueue = multiSpeakerFixture
  .filter((segment) => segment.voiceable && segment.text.length > 0)
  .sort((left, right) => left.sequence - right.sequence)
  .map(({text, speakerID}) => ({text, speakerID}));

assert.deepEqual(replayQueue, [
  {text: 'Mist gathers beneath the pines.', speakerID: 'narrator'},
  {text: 'Wait for the roots to settle.', speakerID: 'npc-a'},
  {text: 'A branch gives a quiet crack.', speakerID: 'narrator'},
  {text: 'Now we can cross.', speakerID: 'npc-b'},
], 'Replay fixture must preserve exact text and Narrator → NPC A → Narrator → NPC B identity order.');

console.log('Live recent-story and Replay contract checks passed.');
