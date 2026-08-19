# Wayfolio SwiftUI Starter v1

This is the first native production foundation for Wayfolio. It deliberately moves the project away from flattened screenshot UI and into reusable SwiftUI components.

## What already works in this starter

- Native SwiftUI app lifecycle.
- Persistent full-screen Wayfolio shell.
- Real iOS safe-area behavior; decorative background can extend edge-to-edge while controls stay in the safe area.
- Fixed header, back/profile controls, right quick rail, bottom dock, and central medallion.
- Five persistent destinations: Guide, Entries, Map, Notes, More.
- Separate navigation paths for each top-level destination.
- Functional Entries screen with search, filters, adaptive grid, and real buttons.
- Functional Entries → Field Guide → Back flow.
- One reusable Field Guide template populated from SwiftData.
- SwiftData persistence and first-launch sample seeding.
- Mossglow Sprinter and Lanternshell Tortoise prototype artwork slots.
- Reusable palette, typography, spacing, surfaces, progress strip, filter chip, entry card, and Chroma glow primitive.
- Functional Hemlock Map prototype with pinch-to-zoom, drag-to-pan, and reset.
- Functional Notes prototype with real note cards and an add-note composer.
- More remains a structured placeholder for future feature modules.
- Presentation-only live DM event channel foundation with independent voice,
  SFX, ambience, music, and UI audio buses.

See `AUDIO_ARCHITECTURE.md` for cue folders, event examples, and endpoint setup.

## Open it

1. On a Mac, open `Wayfolio.xcodeproj` in Xcode.
2. Select the **Wayfolio** target.
3. Under Signing & Capabilities, choose your Apple Development team.
4. Pick an iPhone simulator or your connected iPhone.
5. Build and run.

The project targets iOS 17+ because SwiftData is part of the first production architecture.

## Important visual rule

The phone bezel, Dynamic Island, and home indicator are **not** drawn into app artwork. iOS owns the real device geometry. Wayfolio's background extends edge-to-edge; the app shell keeps readable controls within the safe area.

## Current prototype art

The Mossglow and Lanternshell assets are cropped from previously approved Wayfolio reference screens so the first functional build has recognizable content. They are temporary prototype assets. Production creature art should eventually be exported/generated as clean standalone art without UI baked into it.

## Next recommended implementation order

1. Tune shell dimensions on the actual target iPhone.
2. Lock final type scale, spacing, brass/parchment materials, and button states.
3. Replace prototype creature crops with clean standalone artwork.
4. Add the approved Chroma motion system: Chroma Flow, Scan Lock, Progress Conduction, Medallion Pulse, Discovery Bloom.
5. Convert Map prototype into data-backed points/regions.
6. Persist Notes in SwiftData and add tags/search.
7. Build More modules: Character, Inventory, Crafting, Companions, Quests.
8. Add CloudKit only after local state is stable.
