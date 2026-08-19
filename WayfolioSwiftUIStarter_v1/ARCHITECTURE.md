# Wayfolio Production Architecture v1

## Principle

**Structure is code. Art is content. State is data. Motion attaches to components.**

Generated full-screen mockups are design references only. They are not the production interface.

## Shell

`WayfolioShell` owns all geometry shared across screens:

- edge-to-edge navy/brass background
- safe-area-aware header
- back/profile controls
- fixed right quick rail
- fixed bottom dock
- central medallion
- flexible content viewport

Feature screens never redraw these elements.

## Navigation

Primary destinations are:

- Guide
- Entries
- Map
- Notes
- More

Each destination owns a separate navigation path so future work can preserve position within each section. The first implemented route is `WayfolioRoute.creature(UUID)`.

## Persistence

`CreatureRecord` is a SwiftData model. The app attaches one model container at the app scene. Entries use `@Query`, and sample data is seeded only when the store is empty.

The current model is intentionally small. Do not expand it with every possible campaign property at once. Add schema fields when a real feature needs them.

## Design system

The starter defines:

- `WayfolioPalette`
- `WayfolioMetrics`
- `WayfolioTypography`
- parchment/navy surfaces
- `ChromaGlow`
- `WayfolioProgressStrip`
- `WayfolioFilterChip`
- `EntryCard`

Future UI should consume these tokens/components instead of introducing one-off values.

## Safe areas and corners

No hard-coded iPhone corner mask is used. The system display owns its physical corner radius, Dynamic Island, and home-indicator geometry. Wayfolio's decorative background ignores the safe area; interactive content does not.

## Art contracts

Production content art should be delivered as clean assets with no UI text, buttons, frames, or progress bars. Creature hero art should target a reusable wide slot and preserve safe subject margins.

## Motion contracts

Motion should target semantic states, for example:

- `card.isSelected`
- `entry.isNewDiscovery`
- `scan.isActive`
- `progress.value`
- `medallion.isAttentionSource`

Never attach production animation to screenshot x/y coordinates.
