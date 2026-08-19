# Audio and Dialogue Preparation Package

This directory is the implementation contract between the central DM host, the
shared presentation screen, and player Wayfolios.

- `AudioCueCatalog.json`: available semantic cues and playback defaults.
- `PRESENTATION_PROTOCOL.md`: event envelope, routing, reconnection, and safety.
- `VOICE_DIRECTOR.md`: voice continuity, queueing, mixing, and fallbacks.
- `hemlock_presentation_fixture.json`: the first public/private acceptance test.

Integration is complete when the fixture passes all assertions on three roles:
the private DM host, one shared screen with speakers, and Renn's Wayfolio.
