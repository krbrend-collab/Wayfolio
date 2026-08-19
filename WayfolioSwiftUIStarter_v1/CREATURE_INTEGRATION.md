# Wayfolio Creature Integration Architecture

## Status

This document maps the approved Creature Integration Blueprint onto the current SwiftUI/SwiftData production app without exposing DM-only campaign secrets in the player client.

Companion visual and responsive device rules are defined in `RESPONSIVE_VISUAL_PRESENTATION.md`, including creature image roles plus the current player-facing visual baselines for Renn Hazel and Yūgen.

## Core rule

**One creature canon, multiple projections.**

The live Wayfolio app is the player-facing client. It should render only information the player has actually discovered. Complete creature canon, hidden evolutions, secret abilities, encounter triggers, and other DM-only facts must remain outside the public iOS repository and outside player-facing payloads.

This is especially important because the `krbrend-collab/Wayfolio` repository is public.

## Existing architecture to preserve

The current production architecture already establishes the correct foundation:

- Structure is code.
- Art is content.
- State is data.
- `WayfolioShell` owns shared screen geometry.
- Feature views consume shared design-system components.
- SwiftData provides local persistence.
- `CreatureRecord` currently drives Entries and Field Guide views.
- Production creature art is a clean reusable asset, not a flattened UI screenshot.

Do not replace those principles.

## Current limitation

`CreatureRecord` currently combines several concerns:

- species identity
- player-facing descriptive content
- discovery completion
- unknown notes
- artwork lookup
- companion eligibility

That is appropriate for the first vertical slice, but it should not become the full campaign canon model. In particular, DM-only creature truth must never be added directly to this public client model.

## Target architecture

### 1. Player client: Xcode / SwiftUI / SwiftData

The Wayfolio app stores and renders **player-safe projections** only.

Recommended client-side concepts:

- `CreatureRecord` — player-visible species entry/projection; retain initially to avoid unnecessary migration churn.
- `CreatureDiscoveryState` — what the player has seen, identified, studied, or mastered.
- `CreatureInstanceRecord` — individual creature state for bonded companions or important recurring individuals.
- `CreatureEvolutionLink` — revealed evolution relationships only.
- `CreatureSightingRecord` — optional map/history projection when the Map feature becomes data-backed.

The client should never infer hidden facts from incomplete data.

### 2. Authoritative campaign runtime

A separate private runtime source owns:

- complete creature canon
- hidden evolution stages
- secret traits and abilities
- encounter eligibility and spawn conditions
- unrevealed ecology
- DM-only quest hooks
- authoritative individual creature state
- durable discovery events

The runtime sends only a filtered player-safe projection to Wayfolio.

### 3. Discovery filter

All authoritative creature data passes through a discovery filter before reaching the app.

Suggested discovery states:

- `unknown`
- `sighted`
- `identified`
- `studied`
- `mastered`

The filter determines:

- displayed name
- visible artwork state
- visible ecology
- visible anatomy
- visible abilities
- visible evolution relationships
- companion information
- whether an unknown/locked section appears at all

### 4. Presentation events

Temporary effects such as:

- scan pulse
- discovery bloom
- new-entry glow
- evolution reveal animation
- medallion attention pulse
- creature-identification chime

are presentation events and do not themselves mutate durable campaign state.

Durable discovery, bond, evolution, and sighting changes are runtime state changes.

## Recommended client folder additions

Add only as implementation requires them:

```text
Wayfolio/
├── Models/
│   ├── CreatureRecord.swift                  # existing player-facing projection
│   ├── CreatureDiscoveryState.swift          # add first
│   ├── CreatureInstanceRecord.swift          # add with Companions
│   ├── CreatureEvolutionLink.swift           # add with evolution UI
│   └── CreatureSightingRecord.swift          # add with data-backed Map
│
├── CreatureSystem/
│   ├── CreatureRepository.swift              # client-facing data access
│   ├── CreatureDiscoveryProjector.swift      # maps runtime payloads to visible state
│   └── CreatureSyncService.swift             # transport boundary when runtime sync lands
│
├── Features/
│   ├── Entries/
│   ├── FieldGuide/
│   ├── Companions/                           # future
│   └── Map/                                  # future data-backed creature sightings
```

Do not create every file at once. Add each piece when its vertical slice is implemented.

## First implementation slice

The first creature-system integration should prove only this loop:

1. Load a creature entry.
2. Persist a discovery state separately from species text.
3. Render different Field Guide content for `sighted` vs `identified` vs `studied`.
4. Update discovery state through one explicit runtime-style event.
5. Confirm the view updates from data rather than UI-local assumptions.
6. Confirm no hidden/unrevealed fields exist in the player payload.

This should be implemented before companions, hidden evolutions, or encounter generation are wired into the app.

## `CreatureRecord` migration strategy

Do **not** replace the existing model immediately.

Phase 1:

- keep `CreatureRecord`
- add a stable species identifier if needed for runtime sync
- move discovery status out of generic `completion` as the first real schema extension
- keep current prototype data working

Phase 2:

- introduce separate discovery state
- derive progress/completion from discovered fields rather than storing it as an arbitrary percentage
- adapt `FieldGuideView` to render sections from discovery state

Phase 3:

- add individual creature records for companions
- add revealed evolution links
- add sightings/map integration

## Hidden slime evolution rule

The currently visible slime sheets represent known/public stages only.

At least two later evolution stages may exist as DM-only canon. Those stages must not be stored in the public Wayfolio repository, bundled app data, prototype sample data, or player-facing JSON. They enter the client only after the campaign runtime commits their discovery.

## Art integration

Follow the existing art contract:

- clean standalone creature art
- no baked UI text, frames, buttons, or progress bars
- reusable hero-safe composition
- stable asset IDs linked to species IDs
- visual presentation governed by the approved Wayfolio Chroma Cel / Luminous Ledger system

Field Guide artwork and full design-authority references are content assets; they are not the data authority for mechanics or discovery state.

The detailed responsive presentation contract—including phone crops, shared-device hero/habitat views, companion portraits, slime evolution display, and player-character image roles—is defined in `RESPONSIVE_VISUAL_PRESENTATION.md`.

## Runtime event examples

Durable events:

```text
creature.sighted
creature.identified
creature.studied
creature.bonded
creature.evolution_revealed
creature.sighting_recorded
```

Presentation-only events:

```text
creature.scan_pulse
creature.discovery_bloom
creature.entry_glow
creature.evolution_reveal_animation
```

## Integration with other Wayfolio modules

The same creature identity should later feed:

- Entries / Field Guide — discovery-filtered species projection
- Map — known habitats and player-known sightings
- Notes / Journal — observations and encounter history
- Companions — individual bond state
- Inventory / Crafting / Remedies — only discovered and player-accessible material relationships
- Quests — player-visible creature objectives and clues

No feature module should maintain a separate independent copy of creature canon.

## Guardrails

1. Never put DM secrets in the public Wayfolio repository.
2. Never use chat history as durable campaign state.
3. Never let UI state become the mechanical source of truth.
4. Never bake discovery progress into artwork.
5. Never expose hidden evolutions simply because their assets exist.
6. Preserve the existing shell, design-system, safe-area, and motion architecture.
7. Add schema only when a real vertical slice needs it.

## Next code change

The next code change should be a small, isolated vertical slice adding an explicit discovery-state model and adapting one Field Guide entry to render differently at multiple discovery levels while preserving the existing Entries → Field Guide → Back flow.
