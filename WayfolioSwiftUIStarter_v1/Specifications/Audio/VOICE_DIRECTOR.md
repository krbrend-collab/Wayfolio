# Wayfolio Voice Director v1

## Purpose

The Voice Director converts semantic dialogue instructions into consistent
speech while keeping dialogue text authoritative and speech optional. The DM
chooses what is said; the Voice Director chooses the established voice and safe
performance parameters.

## Initial voice registry

| Speaker ID | Role | Baseline delivery | Fallback |
|---|---|---|---|
| `narrator` | Public narration | Warm, measured, observant; restrained wonder | System narrator |
| `renn` | Player-character readback only | Grounded, attentive, youthful confidence | Captions only |
| `unknown_voice` | Private unidentified speaker | Quiet, close, ambiguous; never caricatured | System narrator |

NPCs receive stable IDs before their first voiced line. A speaker's voice must
not change between sessions unless the campaign explicitly changes it.

## Dialogue request

The synthesizer receives `line_id`, `speaker_id`, text, performance, language,
and optional pronunciation entries. It returns an audio resource plus timing
metadata for captions. Cache keys include normalized text, speaker profile
version, language, and performance—not scene secrets or player identity.

## Performance rules

- Directions describe delivery, not rewritten content.
- Preserve names, numbers, rules terms, and player choices verbatim.
- Never infer accents from race, species, culture, or disability.
- Avoid shouting peaks; intensity comes from pacing and tone first.
- Public dialogue targets shared speakers.
- Private dialogue targets only the named player's Wayfolio.
- Renn is not automatically voiced when the player makes a choice. Player
  agency takes precedence over cinematic readback.

## Queue behavior

Normal lines queue in sequence. Important lines may replace background chatter.
Critical lines may interrupt after a short fade. Replaying a line uses its
existing audio and does not emit a new gameplay event. Skipping speech leaves
the complete caption visible long enough to read.

## Failure behavior

If generation is slow, show the caption immediately and keep gameplay usable.
If generation fails, retain captions and record a presentation diagnostic. Do
not synthesize a different sentence, retry indefinitely, or block the session.

## Mix policy

- Voice bus: `1.0` default.
- While public dialogue plays, music ducks to 45% of its current level and
  ambience to 65%, using a 180 ms attack and 450 ms release.
- World one-shots do not duck voice; their authored loudness must protect speech.
- Private phone dialogue ducks that phone's UI sounds only, not shared audio.
- Provide captions, replay, voice mute, and reduced-sudden-sound preferences.

## Production checklist for each voice

Record the provider/model, voice ID, profile version, approved sample line,
pronunciation dictionary, allowed emotional range, and fallback. Never store API
keys, provider secrets, or generated private dialogue in the cue catalog.
