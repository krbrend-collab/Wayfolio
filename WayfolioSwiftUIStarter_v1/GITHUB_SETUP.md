# GitHub handoff

A local Git repository is already initialized and contains the foundation commit.

Recommended remote repository name:

`wayfolio-ios`

Recommended visibility:

Private while the campaign/app architecture is still evolving.

Suggested branch model:

- `main` — always runnable
- `feature/shell-polish`
- `feature/chroma-motion`
- `feature/map-data`
- `feature/notes-persistence`

Do not mix this native iOS app into the existing Wayfolio voice-proxy repository; the app and voice service have different responsibilities and should remain independently deployable.
