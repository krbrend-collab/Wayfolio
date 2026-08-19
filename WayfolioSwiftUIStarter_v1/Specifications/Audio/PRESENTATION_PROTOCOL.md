# Wayfolio Presentation Protocol v1

## Boundary

Presentation events may display text, play audio, and request transient player
attention. They never change inventory, health, discoveries, quest progress,
roll results, or authoritative campaign state. Gameplay changes use the separate
session protocol and are resolved by the central host.

## Device roles

- `dm`: private central-host controls and hidden state.
- `screen`: public group display and shared speakers.
- `wayfolio`: a player's private phone and local UI audio.

## Event envelope

Every event sent by the host uses this envelope:

```json
{
  "protocol": "wayfolio.presentation.v1",
  "event_id": "evt-unique-id",
  "sequence": 42,
  "session_code": "HEMLOCK",
  "scene_id": "lantern-road-01",
  "sent_at": "2026-08-18T22:00:00Z",
  "audience": {"kind":"shared"},
  "event": {"type":"sound_effect","cue":"wood_bridge_creak","volume":0.7}
}
```

Audience forms are `{"kind":"shared"}`, `{"kind":"player","player_id":"renn"}`,
and `{"kind":"players","player_ids":["renn","mira"]}`. The host must never
broadcast private events and rely on clients to hide them.

Receivers ignore duplicate `event_id` values. `sequence` orders events within a
session; reconnecting clients request current persistent presentation state and
do not replay transient events.

## Event types

### Dialogue

```json
{
  "type": "dialogue",
  "line_id": "lantern-road-narration-01",
  "speaker_id": "narrator",
  "text": "Evening settles over Hemlock Village.",
  "performance": "warm, measured, quietly mysterious",
  "priority": "normal",
  "interrupt": "queue",
  "caption": true
}
```

`interrupt` is `queue`, `replace_lower_priority`, or `immediate`. Priorities are
`background`, `normal`, `important`, and `critical`. Dialogue always includes
text so captions remain available when voice generation fails.

### One-shot sound

```json
{"type":"sound_effect","cue":"wood_bridge_creak","volume":0.7}
```

Use `ui_sound` only for phone-local presentation feedback. Public world effects
use `sound_effect` and normally target `shared`.

### Ambience

```json
{"type":"ambience","action":"play","cue":"hemlock_forest","volume":0.5,"fade_duration":1.5}
```

`action` is `play` or `stop`. Ambience is persistent scene state and is included
in reconnect snapshots.

### Music

```json
{"type":"music","action":"play","cue":"forest_exploration","volume":0.45,"intensity":0.3,"fade_duration":2.0}
```

Music is independent persistent scene state. Silence is represented by `stop`,
not by selecting a silent track.

### Presentation control

```json
{"type":"audio_control","action":"stop_all","fade_duration":0.25}
```

Supported actions are `stop_all`, `pause`, and `resume`. Only the host emits
these commands. A local user mute never sends a session command.

## Acknowledgements

Clients acknowledge only events that need coordination:

```json
{"type":"presentation_ack","event_id":"evt-unique-id","status":"started"}
```

Statuses are `received`, `started`, `completed`, `skipped`, and `failed`.
One-shot UI sounds require no acknowledgement. Dialogue completion may advance
presentation pacing but must not independently advance campaign state.

## Reconnection snapshot

The host supplies the current scene, ambience, music, active caption/dialogue,
and monotonic sequence. It does not resend completed dialogue or one-shots.

## Safety limits

- Cue IDs are catalog identifiers, never file paths or URLs.
- Volume and intensity are clamped to `0...1`.
- Unrecognized events and cues fail silently with diagnostics.
- Missing presentation media never blocks player choices or campaign progress.
- Private dialogue is delivered only to the targeted authenticated player.
