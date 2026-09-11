import assert from 'node:assert/strict';
import {normalizeVoiceAssignmentState, resolveVoiceAssignment, voiceAssignmentProjection} from './voice-assignment.mjs';

const registry = {
  default_profile:'narrator',
  profiles:{
    narrator:{aliases:['dm']},
    wayfolio:{aliases:['system']},
    soren:{aliases:['soren_hazel']},
    unknown_voice:{aliases:['unknown']},
  },
};

let state = normalizeVoiceAssignmentState({}, registry, '2026-09-09T00:00:00.000Z');
let result = resolveVoiceAssignment(state, {speakerID:'Soren Hazel', requestedProfileID:'soren', registry,
  now:'2026-09-09T00:00:01.000Z'});
assert.equal(result.assignment.voice_profile_id, 'soren');
assert.equal(result.changed, true);
state = result.state;

result = resolveVoiceAssignment(state, {speakerID:'soren_hazel', requestedProfileID:'narrator', registry,
  now:'2026-09-09T00:00:02.000Z'});
assert.equal(result.assignment.voice_profile_id, 'soren');
assert.equal(result.changed, false, 'a later event must not silently recast an established speaker');

const restored = normalizeVoiceAssignmentState(JSON.parse(JSON.stringify(result.state)), registry,
  '2026-09-10T00:00:00.000Z');
result = resolveVoiceAssignment(restored, {speakerID:'soren_hazel', registry,
  now:'2026-09-10T00:00:01.000Z'});
assert.equal(result.assignment.voice_profile_id, 'soren');
assert.equal(result.changed, false, 'relaunch must preserve the campaign assignment');

result = resolveVoiceAssignment(result.state, {speakerID:'new_npc', requestedProfileID:'unknown_voice', registry,
  now:'2026-09-10T00:00:02.000Z'});
assert.equal(result.assignment.voice_profile_id, 'unknown_voice');
assert.equal(voiceAssignmentProjection(result.state).assignments.length, 2);

console.log('Persistent speaker voice assignment, no-recast behavior, and restart restoration passed.');
