# Wayfolio Audio Architecture

Audio is presentation-only. Incoming DM commands may play or stop audio, but
they cannot mutate campaign models, inventory, notes, discoveries, or navigation.

## Mix buses

The audio engine keeps independent `voice`, `sfx`, `ambience`, `music`, and `ui`
buses. Each has its own volume and mute state. Voice playback has a dedicated API
so a voice provider does not need to share effect or music state.

Bundled cues are resolved by semantic ID and audio category:

- `Wayfolio/Audio/UI`
- `Wayfolio/Audio/SFX`
- `Wayfolio/Audio/Ambience`
- `Wayfolio/Audio/Music`
- `Wayfolio/Audio/Voice`

Supported file types are `m4a`, `wav`, `aiff`, `mp3`, and `caf`. A missing cue is
silently ignored so presentation audio never blocks the interface or game flow.

## Live event endpoint

Set `WAYFOLIO_PRESENTATION_WEBSOCKET_URL` in the app Info.plist or generated build
configuration to a `wss://` endpoint. When it is absent, the app remains fully
functional with local UI cues only.

Each WebSocket message is one JSON object. Examples:

```json
{"type":"ui_sound","cue":"discovery_reveal","volume":0.8}
{"type":"sound_effect","cue":"wood_bridge_creak","volume":0.7}
{"type":"ambience","action":"play","cue":"hemlock_forest","volume":0.5}
{"type":"ambience","action":"stop"}
{"type":"music","action":"play","cue":"forest_exploration","intensity":0.4,"fade_duration":1.5}
{"type":"music","action":"stop","fade_duration":2.0}
```

Optional envelope fields are `id` (UUID), `sequence` (integer), and `sent_at`
(ISO-8601). Cue identifiers cannot contain paths; the app alone maps them to
bundled resources.
