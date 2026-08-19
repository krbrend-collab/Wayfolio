# Wayfolio — Next Build Steps

## Milestone A: Shell validation

Test on the intended iPhone in portrait orientation.

Validate:
- header clears the real Dynamic Island/status region
- bottom dock clears the home indicator
- right quick rail does not obscure scroll content
- medallion stays centered over the dock
- Entries can scroll while shell stays fixed
- text remains readable at default and larger Dynamic Type sizes

## Milestone B: First vertical slice

Prove this loop with real persisted data:

Entries → Mossglow → Back → Lanternshell → Back → switch to Map → return to Entries.

Acceptance criteria:
- no shell position drift
- each tab retains its navigation path
- progress values are data-driven
- filters/search are functional
- no UI text is baked into artwork

## Milestone C: Visual fidelity

Replace prototype surfaces with final Luminous Ledger treatments while keeping component dimensions stable.

Add:
- botanical corner ornament as vector/SVG or SwiftUI Shape assets
- refined brass separators
- final rabbit profile medallion art
- selected/pressed/updated/danger component states
- clean standalone Mossglow/Lanternshell art

## Milestone D: Motion

Implement in this order:
1. Medallion Pulse
2. Progress Conduction
3. Chroma Flow
4. Scan Lock
5. Discovery Bloom
6. Dungeon danger state

Animations should respect Reduce Motion.

## Milestone E: Feature modules

Map data/markers → Notes persistence/search → Character → Inventory → Crafting → Companions → Quests.
