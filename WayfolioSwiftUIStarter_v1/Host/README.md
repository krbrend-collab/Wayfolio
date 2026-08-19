# Wayfolio Central Host

This is the first local-network multiplayer slice. The host owns the session,
the shared screen shows public information, and each phone joins as a Wayfolio.

1. Run `npm install` once in this folder.
2. Run `npm start`.
3. Open `http://localhost:8787/dm` for private DM controls.
4. Open `http://localhost:8787` on the shared display.
5. In Renn's Wayfolio, open More and join with the Mac's local IP and code `HEMLOCK`.

On the shared screen, select **Enable audio** once; browsers require a player
gesture before sound can begin. The private DM page can then control shared
ambience, music, world effects, creature sounds, dialogue, and emergency stop.
Public audio never broadcasts to player Wayfolios. Reconnecting shared screens
restore current ambience and music without replaying old one-shot effects.

The host consumes the canonical files in `Specifications/Audio` and serves the
bundled assets from `Wayfolio/Resources/Audio`; do not maintain duplicate copies.

Do not put the private DM page on the shared display.
