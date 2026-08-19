# Audio and Dialogue Preparation Package

This directory is the implementation contract between the central DM host, the
shared presentation screen, and player Wayfolios.

- `AudioCueCatalog.json`: available semantic cues and playback defaults.
- `CreatureAudioProfiles.json`: creature type and named-creature cue routing.
- `PresentationEvent.schema.json`: machine-readable event validation contract.
- `PRESENTATION_PROTOCOL.md`: event envelope, routing, reconnection, and safety.
- `VOICE_DIRECTOR.md`: voice continuity, queueing, mixing, and fallbacks.
- `hemlock_presentation_fixture.json`: the first public/private acceptance test.

Integration is complete when the fixture passes all assertions on three roles:
the private DM host, one shared screen with speakers, and Renn's Wayfolio.

Creature sound lookup uses this order: named creature override, creature type,
then the catalog fallback. Behavior-specific calls (`idle`, `attack`, `hurt`,
and others) can be added without changing that routing rule. Version 1 ships an
`alert` sound for ten creature types.

Run `python3 Tools/validate_audio_package.py` from the starter directory to
check JSON, cue references, routing, WAV format, clipping, and loop boundaries.
