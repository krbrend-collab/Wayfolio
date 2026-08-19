# Wayfolio Responsive Visual Presentation System

## Purpose

Wayfolio uses one visual canon across phones and larger shared devices, but the composition changes with viewing context. Phone views prioritize fast identity, discovery, and personal use. Larger shared-device views prioritize ecology, comparison, party visibility, and collaborative reading.

The system applies to both **creatures** and **player characters**.

## Shared visual language

All creature and character art should remain within the approved Wayfolio visual family:

- Luminous Ledger interface foundation
- Chroma Anime / Chroma Cel rendering
- stronger cel-shading rather than painterly realism
- grounded materials first, functional color second, luminous spectacle last
- clean silhouettes and readable anatomy
- magical chroma used selectively for state, magic, rarity, discovery, or change
- clean standalone assets with no baked UI text, buttons, progress bars, or device frames

Device changes may alter crop, environment, information density, and composition. They must not change anatomy, costume canon, coloration logic, or species/character identity.

---

# 1. Creature Visual Package

A creature can expose several player-safe image roles. Not every species requires every role.

### `entryCropAsset`
Compact, high-read crop for catalog cards, search results, map callouts, and notifications.

### `heroAsset`
Primary reusable creature illustration with enough environment to establish mood and ecology.

### `fieldPlateAsset`
Full Wayfolio Chroma Cel Field Plate: large contextual hero scene plus restrained specimen/anatomy strip.

### `unknownSilhouetteAsset`
Player-safe pre-identification form. May be a silhouette, obscured crop, fogged render, or scan-state image.

### `companionPortraitAsset`
Optional relational portrait for bonded/tameable creatures. More intimate and character-focused than the ecological field plate.

### `wideHabitatAsset`
Optional wide scene for shared displays, pack/herd behavior, migration, evolution comparison, or environmental storytelling.

## Creature discovery image rules

- `unknown` — silhouette/obscured presentation only
- `sighted` — partial real image may appear; identity may remain hidden
- `identified` — full hero art becomes available
- `studied` — field plate and anatomy/reference views may appear
- `mastered` — all **revealed** relationships, evolution links, behavior variants, and companion/ecology views may appear

Hidden evolutions or DM-only forms must not be bundled in the player app simply because a visual asset exists.

---

# 2. Phone Creature Presentation

The phone is a personal field instrument. It should feel focused, quick, intimate, and spoiler-aware.

## Entry cards

Prioritize:

1. silhouette / face / strongest species read
2. elemental or magical identity
3. discovery state

Use the compact entry crop rather than shrinking the full field plate.

## Creature detail header

Use the hero asset with more breathing room than the catalog card. Enough environment should remain to establish mood, but the creature remains dominant.

## Deep Field Guide view

The full plate may appear deeper in the scroll. Lower specimen/anatomy information should respect discovery state.

## Slimes on phone

Show the currently known stage prominently. Revealed evolution stages can appear as a compact progression; hidden stages are omitted or locked without visual spoilers.

---

# 3. Larger Shared-Device Creature Presentation

A shared iPad/tabletop/display layout should not simply enlarge the phone UI.

Use a dedicated **Field Research Layout**:

### Main visual zone
Large hero or habitat illustration with increased environmental context.

### Information zone
Species name, discovery level, known ecology, behavior, and current observations.

### Reference zone
Revealed specimen strip, evolution rail, scale, related species, materials, or encounter observations.

Shared displays are especially appropriate for:

- pack/herd behavior
- evolution comparisons
- known slime stages side by side
- migration events
- party discussion
- companion/species comparison

The larger screen may show more information simultaneously, but it may never reveal data above the player's discovery state.

---

# 4. Character Visual Package

Player characters use the same responsive principle, but their imagery prioritizes **identity and relationship** rather than ecological discovery.

Recommended image roles:

### `characterCardPortrait`
Head-and-shoulders or upper-body portrait for navigation, party strips, profile cards, and compact status areas.

### `characterHeroAsset`
Primary full/three-quarter character illustration showing canonical silhouette, clothing, species traits, and important equipment.

### `characterFullBodyAsset`
Clear standing full-body reference, especially useful for shared devices, equipment screens, and outfit verification.

### `characterTurnaroundAsset`
Optional front/back/three-quarter reference used for design authority and equipment placement; usually not a primary gameplay screen.

### `characterGearDetailAssets`
Optional close views for distinctive weapons, focus items, protective equipment, or companion-relevant gear.

### `characterSceneAsset`
Optional contextual illustration for major story states or shared-device presentation.

## Phone character presentation

Phone views should emphasize:

- portrait/face
- current resources/status
- current outfit/loadout
- immediate equipment
- companion relationship if relevant

Avoid trying to fit a full turnaround or large equipment breakdown into the primary character header.

## Shared-device character presentation

Larger displays can use:

- full-body hero art
- party members side by side
- current equipment layout
- larger gear callouts
- stance/action reference
- companion placement

Shared-device character imagery should make the party visually legible at a glance.

---

# 5. Current Player-Character Visual Canon

This section contains only player-facing visual information suitable for the public client. It is not a rules or secret-lore authority.

## Renn Hazel — current locked visual baseline

- male Harengon; human-faced / Viera-inspired visual language, but not a Viera or hybrid
- approximately 5'11" / 180 cm to the head, excluding ears
- lean, toned, highly agile build with relatively narrow waist and developed lower-body musculature
- youthful, soft-handsome human-like face
- dark tousled curls
- long upright rabbit ears
- compact, fluffy true-rabbit tail
- rabbit lower-leg and foot anatomy; no conventional shoes as the default
- cropped jacket in a dark rich blue
- black top and black pants
- dark brown leather belt with antique-brass hardware
- warm-gray/taupe sash
- dark-brown satchel and leg pouch
- integrated hood; hood lining uses the approved Hemlock Ribbon pattern
- forearm treatment is wrap-dominant in warm gray/taupe with a narrow dark-brown protective leather guard
- protective lower-leg system uses a calf/shin unit and dorsal-foot guard while preserving rabbit-foot function
- four kunai-style daggers
- retractable ring-headed quarterstaff / field tool
- Hemlock-sprig belt locket focus
- herbalist pack
- Wayfolio

Retired visual defaults that must not reappear:

- white button-up shirt
- conventional boots or full sole
- human ears in place of rabbit ears
- bow as default weapon
- staff presented as the spellcasting focus

Renn's character imagery should preserve the approved dark-blue / black / brown / warm-gray palette and the Hemlock protective-clothing logic.

## Yūgen — current confirmed visual baseline

Yūgen is sufficiently defined for a current Wayfolio character slot, but is less visually locked than Renn and should remain updateable as his own character-development work advances.

Confirmed/current baseline:

- young adult male
- slim-to-athletic build, approximately 5'11" / 180 cm
- tousled black hair
- eye direction currently dark to amber/golden
- Japanese-inspired layered robes / outer garments
- principal palette: indigo, midnight/navy, ivory/white, gold, deep blue, with restrained crimson accents
- talismans, cords, beads, tassels, and arm wraps
- three large fluffy fox tails in white / silver-white
- white fox mask with red markings
- Dōkontō lantern with blue flame

The **three tails** and **white fox mask with red markings** are confirmed corrections and should not regress. Exact mask mechanics and some finer build/costume details remain open to future canon updates.

---

# 6. Character vs Creature Presentation Rule

Creature imagery answers:

> What is this species, how does it live, and what have we learned about it?

Character imagery answers:

> Who is this person, what are they carrying/wearing now, and how do they relate to the party and current state?

Therefore:

- Bestiary art should remain ecological and observational.
- Companion art can become relational.
- Player-character art should remain identity/loadout focused.
- Shared-device art may become more cinematic, comparative, or party-oriented.

---

# 7. Implementation Guidance

Do not add every asset field immediately. Introduce them when a real UI slice needs them.

Suggested first additions when production art replaces prototypes:

```text
CreatureRecord / player projection
- entryCropAssetName
- heroAssetName
- fieldPlateAssetName
- unknownAssetName

Future optional projections
- companionPortraitAssetName
- wideHabitatAssetName
```

Character models can later mirror this pattern:

```text
- cardPortraitAssetName
- heroAssetName
- fullBodyAssetName
- equipmentDetailAssetNames
```

Preferred crop metadata may be added only if real assets demonstrate that automatic `scaledToFill` cropping is insufficient.

---

# 8. Visual Authority Rule

The approved creature Field Guide plates and approved character references govern appearance. SwiftUI assets are presentations of that canon, not independent redesigns.

When a design changes in the project, update the canonical reference first, then replace/relink the relevant player-safe assets in Wayfolio.
