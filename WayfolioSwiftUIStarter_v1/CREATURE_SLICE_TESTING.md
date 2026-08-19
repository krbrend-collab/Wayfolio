# Creature Discovery Vertical Slice — Test Checklist

Use this checklist when running the `creature-integration-foundation` branch in Xcode.

## Expected first-run state

- Entries contains a Tubelume record.
- Tubelume begins at `sighted` discovery level.
- Its real species name is not shown while it is only sighted; the card and Field Guide display `Unidentified Creature`.
- Its observed field note is visible.
- Affinity, temperament, habitat, active hours, healing uses, and open questions remain progressively gated.

## Discovery progression

Open the Tubelume Field Guide and use the temporary **Prototype Runtime Event** control.

1. `sighted` → `identified`
   - Tubelume's real name appears.
   - Affinity and temperament unlock.
2. `identified` → `studied`
   - Habitat, active hours, healing uses, and open questions unlock.
3. `studied` → `mastered`
   - The current player-facing record shows as fully studied.
   - The UI explicitly notes that future campaign discoveries may still expand the record.

## Persistence

- Quit and relaunch the app after each stage.
- Confirm the discovery level persists through SwiftData.
- Confirm the Entries card and Field Guide agree after relaunch.

## Existing-flow regression

Confirm the existing production slice still works:

- Entries → creature → Back
- switch Entries → Map → Entries
- search/filter still functions
- other seeded creatures remain visible
- shell/navigation geometry does not change

## Security / spoiler check

- No hidden slime evolution names, descriptions, assets, or reveal conditions are present in the player-facing repo changes.
- No DM-only creature canon is embedded in `CreatureRecord`, `SampleData`, or Field Guide code.

## Known temporary implementation

The **Prototype Runtime Event** button is intentionally a stand-in for the private campaign runtime. It should be removed or disabled once the runtime-to-Wayfolio transport contract is connected.
