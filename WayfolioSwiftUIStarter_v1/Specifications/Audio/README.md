# Audio and Dialogue Preparation Package

This directory is the implementation contract between the central DM host, the
shared presentation screen, and player Wayfolios.

- `AudioCueCatalog.json`: available semantic cues and playback defaults.
- `CreatureAudioProfiles.json`: creature type and named-creature cue routing.
- `CharacterVoiceProfiles.json`: canonical speaker direction plus browser and
  future provider mappings, keyed by stable `speaker_id`.
- `CharacterVoiceProfiles.schema.json`: validation contract for that registry.
- `LocationAmbienceProfiles.json`: seamless location beds with randomized,
  non-repeating environmental details that remain independent from music.
- `ActionSoundProfiles.json`: reusable gameplay actions mapped to shared-world
  or player-private audio cues.
- `EncounterAudioProfiles.json`: exploration, tension, combat, resolution, and
  silence states with dialogue-safe music levels and transition timing.
- `SpellAudioProfiles.json`: semantic spell families resolved to distinct,
  reusable casting sounds.
- `MovementAudioProfiles.json`: terrain and movement-mode routing for natural
  footstep sequences.
- `SceneTransitionProfiles.json`: semantic cues for travel, rest, discoveries,
  danger, combat, victory, camp, doors, and building entry.
- `AudioDirectorRules.json`: conservative public-context inference, priority,
  privacy, and cooldown rules for automatic live-play triggering.
- `PresentationEvent.schema.json`: machine-readable event validation contract.
- `creature_resolution_fixture.json`: expected routing for wolves, bunnies,
  slimes, spirits, named creatures, and fallbacks.
- `PRESENTATION_PROTOCOL.md`: event envelope, routing, reconnection, and safety.
- `VOICE_DIRECTOR.md`: voice continuity, queueing, mixing, and fallbacks.
- `hemlock_presentation_fixture.json`: the first public/private acceptance test.

Integration is complete when the fixture passes all assertions on three roles:
the private DM host, one shared screen with speakers, and Renn's Wayfolio.

Creature sound lookup uses this order: named creature override, exact body-form
and disposition composite, body form, creature type, then the catalog fallback.
Version 1 includes alerts for ten broad types plus twelve form/disposition cues
for soft-bodied, predatory, amorphous, incorporeal, skeletal, swarm, crystalline,
fungal, shell-armored, and floating arcane creatures.

Run `python3 Tools/validate_audio_package.py` from the starter directory to
check JSON, cue references, routing, WAV format, clipping, and loop boundaries.
