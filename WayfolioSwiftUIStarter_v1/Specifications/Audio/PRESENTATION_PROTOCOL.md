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

### Creature sound

```json
{"type":"creature_sound","creature_id":"glimmer_slime","creature_type":"ooze","body_form":"amorphous","size":"small","disposition":"curious","behavior":"move","volume":0.65}
```

The renderer resolves the cue using `CreatureAudioProfiles.json`: named-creature
override, exact body/disposition composite, body form, creature type, then the
fallback profile. This distinguishes a timid bunny from a predatory wolf even
when both are beasts, and supports unusual forms such as slimes and spirits.
Unknown behaviors produce no sound rather than playing an unrelated call.

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

The DM may request an adaptive dramatic state without choosing a file:

```json
{"type":"encounter_audio","state":"tension"}
```

Supported states are `exploration`, `tension`, `combat`, `resolution`, and
`silence`. The host resolves these through `EncounterAudioProfiles.json` into
ordinary presentation-only music and optional stinger events.

Spell sounds are also requested semantically:

```json
{"type":"spell_sound","family":"frost","intensity":0.7}
```

The host resolves the family through `SpellAudioProfiles.json`; unknown
families use the arcane fallback instead of failing or changing game state.

Movement is requested by surface and pace rather than by filename:

```json
{"type":"movement_sound","surface":"gravel","mode":"sneak"}
```

Supported surfaces are grass, dirt, gravel, stone, wood, metal, water, mud,
snow, and bones. Modes are `sneak`, `walk`, `run`, and `heavy`. Unknown surfaces
use dirt; unknown modes use walking.

Scene changes use semantic transition names:

```json
{"type":"scene_transition","transition":"travel_arrival"}
```

Transitions cover doors, entering buildings, camp setup, discoveries, danger
reveals, combat starts, victories, rests, travel departures and arrivals, and
quest completion. They remain transient presentation events.

### Audio director

The host may infer at most one world cue from a public action or public scene
change. Major transitions outrank ordinary transitions, which outrank movement.
Per-category and per-cue cooldowns suppress repetition. Low-confidence text
produces silence. Private player declarations are never inspected for shared
audio, preventing presentation from leaking a hidden action.

The DM may also request the same bounded director explicitly:

```json
{"type":"audio_director","context":"action","text":"I sneak across the wooden bridge."}
```

This produces only presentation events and cannot mutate campaign state.

### NPC arrival and speech

```json
{
  "type":"npc_arrival",
  "npc_id":"koori",
  "archetype":"spellcaster",
  "text":"The lanterns are waking up.",
  "performance":"joyful"
}
```

The host resolves a named NPC first, then the requested archetype, then the
ordinary fallback. It plays one restrained entrance cue and queues speech after
the profile's short entrance delay. Named profiles always retain their stable
voice and pronunciation notes. Unknown NPCs use `unknown_voice` until assigned
a permanent profile. Arrival cooldowns prevent repeated entrances, and captions
remain available if speech playback fails.

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
