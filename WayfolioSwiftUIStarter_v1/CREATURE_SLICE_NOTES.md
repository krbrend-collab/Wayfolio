# Tubelume Creature Discovery Slice — Implementation Notes

This branch introduces the first player-facing creature discovery slice without adding DM-only canon to the public app.

## Implemented

- `CreatureDiscoveryLevel`: unknown, sighted, identified, studied, mastered.
- `CreatureDiscoveryRecord`: separate SwiftData persistence keyed to a creature UUID.
- Wayfolio app model container now includes creature and discovery models.
- Entries and Guide cards render discovery-derived name, descriptor, progress, and companion visibility.
- Field Guide progressively reveals observation, identity, ecology, and practical information by discovery level.
- Tubelume is seeded as the first `sighted` test creature.
- Existing sample creatures seed at `studied` to preserve the starter experience.
- Seed logic now adds missing samples/discovery records instead of running only on an empty store.
- A temporary prototype runtime control advances discovery state for end-to-end testing.

## Deliberately not implemented yet

- No hidden slime evolutions in the client.
- No full private creature canon registry in the public repository.
- No runtime transport/sync layer yet.
- No companion-instance model yet.
- No creature map sightings yet.
- No production Tubelume art asset yet; the slice uses a fallback symbol until a clean standalone asset is integrated.

## Next engineering step after Xcode validation

Replace the temporary prototype discovery button with the real private-runtime event transport and define the smallest player-safe creature projection payload.
