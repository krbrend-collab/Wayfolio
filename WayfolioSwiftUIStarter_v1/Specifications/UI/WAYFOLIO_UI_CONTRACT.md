# Wayfolio UI Contract

Status: **IMPLEMENTED PENDING PHYSICAL ACCEPTANCE** through Wayfolio Development Sync WF-125. Primary Navigation V2, the Spiritbloom shared-iPad pre-session surface, Personal iPhone Wayfolio Login V1, progressive records, persistent voices, and the reusable shared-iPad stage are represented in source and automated fixtures. Approved production media resolves through the Host registry; native bundle media remains bootstrap/fallback only. This document defines presentation and intent boundaries only. Campaign authority remains with the existing host and session systems.

## Spiritbloom shared-iPad pre-session authority (WF-092–WF-093)

- The approved shared-iPad login composition is `wayfolio_ipad_login_v02.png`. The earlier v01 composition is superseded and must not be presented as current production artwork.

- The approved master overlay is `IPAD_LOGIN_PRIMARY_LOCKUP`, centered at approximately 50% x / 48% y and sized to 52% of the viewport width while preserving aspect ratio.
- Reserve the lower 27% of the viewport for the contextual information bar and session action area.
- Five readiness indicators illuminate sequentially. Their visible domain labels remain intentionally unspecified and must not be invented.
- Begin Session remains unavailable until required connection, journey, campaign-state, party, and session readiness checks pass.
- Character sprites render behind the fixed overlay. Pending sprites are solid, extremely dark/desaturated cool-indigo silhouettes; ready sprites use approved full color. Hinosuke follows Yūgen and is not a separate player slot.
- The most recent approved context-bar handoff contains Current Story Checkpoint, Session Information, and Current Location. This later three-field standard supersedes the earlier two-field draft.
- Login portraits are selected only by stable character identity and the `LOGIN_PORTRAIT` semantic role through the Host manifest. Assigned/revealed characters may appear; party branding is a separate layer and rejected drafts are never substituted.
- WF-093 identifies seven approved current portrait identities: Renn, Yūgen, Hinosuke, Lark, Soren, Lupin, and Emrys. Presence in that asset set does not itself reveal a character or add them to the current party.

## Login surface boundary (WF-099)

- The approved Spiritbloom composition is shared-iPad-only. It must not be cropped, scaled, or universalized into the personal iPhone login.
- Personal iPhone Wayfolio Login V1 is now separately approved. Its visual authority is `wayfolio_iphone_login_window_v01_APPROVED.png` in Drive folder `1evDI57HgFTfw1e3n8E1LPWVl7UFxvmsC`.
- Spiritbloom: Awakening and its emblem occupy the top brand hierarchy. `WAYFOLIO DEVICE LOGIN` is the smaller functional label; the Spiritbloom emblem must not be relabeled as Wayfolio branding.
- Required live regions are player/profile selection, device recognition, DM connection, Wayfolio synchronization, Begin Session, Current Story Checkpoint, and Current Location.
- The approved PNG is a visual shell/reference only. All identity, connection, synchronization, readiness, checkpoint, location, loading, error, and action state remains code-rendered and accessible.
- The dynamic environment stays on its own lowest layer. Preserve the reduced-window composition and bottom-edge projection source without baking changing state into artwork.
- The personal iPhone login has no password field, password recovery, or password-based login UI.
- Login controls are real code controls with accessible labels, visible states, and minimum 44-point targets. Flattened artwork never owns interaction or backend truth.
- When approved v02 media is unavailable, the native app uses a neutral Luminous Ledger bootstrap surface and continues connection recovery. It must not silently fall back to superseded v01 as though it were approved.

## Storyteller continuity presentation (WF-097–WF-098)

- ChatGPT threads never own campaign state. The shared Wayfolio campaign state is authoritative across thread replacement and device reconnection.
- Thread-health and rollover controls are host/DM operational state. Player-facing surfaces may show a concise waiting or recovery state but must not expose private transcript, credential, lease, or DM-only diagnostics.
- A safe rollover preserves the pending interaction and resumes without duplicated narration, rolls, damage, inventory changes, or other committed effects.
- Renn and Yūgen may use independent storyteller-thread lifecycles while sharing the same campaign authority.
- Acceptance fixtures F42–F49 govern continuity, including at least one resume through a fresh storyteller thread without the old transcript.

## Equipment quality presentation (current sync)

- Every equippable item carries a `quality_level` integer from 1 through 5 as standard gameplay data.
- Quality may affect effectiveness, reliability, rarity, crafting, and upgrade behavior through configurable rules; the UI must not invent an unapproved numeric curve.
- Inventory, ownership, loot, shops, crafting, rewards, equip, comparison, and detail views must preserve and display quality consistently.
- Use **Protective Gear** for the equipment family; do not introduce a generic **Armor** family label.
- Current approved Level 1 Protective Gear identities are Cuirass, Bracers, Greaves, Pauldrons, Gauntlets, Helmet, Mask, and Waist Guard. Earlier Level 2/3 studies are superseded.

## Device roles

- Personal Wayfolio: portrait phone, fixed orientation, player-private information and intent entry.
- DM Wayfolio: portrait phone, same shell, DM tools visible only for an authorized DM role.
- Shared screen: landscape iPad, 4:3 responsive presentation and table interaction.

## Visual references

Structural concepts are stored in `Specifications/UI/Concepts/`:

- `character-structure.png`
- `character-final-skin.png`
- `carried-items-list-final.png`
- `equipped-loadout-final.png`
- `item-record-hemlock-locket-final.png`
- `observed-creatures-list-final.png`
- `creature-record-crown-hare-final.png`
- `pack-structure.png`
- `live-response-structure.png`
- `journal-structure.png`
- `world-structure.png`
- `profile-menu-structure.png`
- `shared-ipad-dialogue-waiting.png`
- `shared-ipad-dice-choice.png`
- `shared-ipad-physical-entry.png`
- `shared-ipad-digital-roll.png`

The structure images define hierarchy and component placement. `character-final-skin.png` defines the master material, illumination, icon, texture, and typography direction to inherit across the other personal destinations. These are not flattened runtime assets. SwiftUI and shared-screen code must render the approved background, artwork, text, controls, and effects as separate layers.

### World-art integration authority

The Luminous Ledger references above govern the interface. Character, crowd, location, and environmental artwork embedded by that interface follows the separate **World Visual Design Philosophy — Architecture, Fashion & Technology — V2** authority recorded by WF-017. The two systems are complementary and must not be flattened into one image-generation style.

- The campaign world's material culture is late-19th/early-20th-century-adjacent fantasy entering its own modernity, not medieval or Renaissance-European fantasy.
- Hemlock combines ecological/biophilic construction, restrained Art Nouveau organic geometry, selected Chinese garden-space and threshold ideas, and Harengon craft culture.
- Hemlock is clean, maintained, sophisticated, modest in scale, and integrated with a living temperate forest. Nature integration does not mean decay, hollow-tree rooms, or damage to roots and habitat.
- Modernity must read before magic through tailoring, professional specialization, precision hardware, compact equipment organization, glazing, fabrication, and culturally evolved traditional forms.
- Hemlock Harengon use humanlike faces without rabbit muzzles or human ears, true rabbit ears, compact rabbit tails, humanlike hands, and rabbit-influenced semi-digitigrade lower legs and feet. Clothing must be engineered for that anatomy.
- Technology uses precision craft plus selective magical information systems. Do not infer steampunk clutter, contemporary consumer electronics, or unestablished global infrastructure.
- Approved written canon controls facts and spatial relationships. Approved visual work controls presentation; incidental decorative details do not silently become gameplay canon.

World-art media uses stable location IDs and semantic presentation roles. Folder order and newest timestamps are never selection authority. Built locations have two separate baseline roles:

1. **Wayfolio location-record media:** clean location artwork shown inside a discovered World record. It is not a fake phone screen, parchment card, or precomposed Wayfolio UI.
2. **Shared iPad exterior/approach:** a separate landscape, full-bleed 4:3 gameplay scene showing the exterior, approach, or outside playable state. The portrait record never substitutes for this baseline.

Additional shared-iPad roles are registered only when they contribute distinct playable information: interior or activity zones, first-person shop/service counter interactions, first-person seated dining, first-person table service, and separately stored weather/time states. Shop and service scenes use the player side of the counter. Restaurants, cafés, and tea houses support counter-order, seated-table, and table-service roles when those interactions exist. Open landscapes use a representative 4:3 gameplay landscape as the exterior-equivalent rather than inventing a building.

Reuse an approved image only when it truly satisfies the same semantic role. Do not manufacture redundant screens merely to fill an asset quota. Newly generated images remain in review until the user explicitly approves them. Explicitly approved assets are registered by stable subject/location ID, semantic role, context, visibility, and knowledge scope; folder presence alone is not approval.

Current Hemlock identity corrections from WF-025:

- Stable location `hemlock-location-04` displays as **Garden Shrine**. `Quiet Shrine` and `Hemlock Forest Shrine` are aliases for the same location, not separate records. Main Shrine Grove remains distinct.
- **Commons Plaza** (`2/32`) and supplemental **Market Street** are distinct locations and asset sets. Market Street does not renumber the 32-location sequence.
- **Root & Kettle** (`20/32`) is a bright daytime tea house/café and community kitchen, not a generic tavern.

### App icon

The installed iOS/iPadOS icon master is `Wayfolio/Assets.xcassets/AppIcon.appiconset/wayfolio-app-icon-1024.png`. It uses the Luminous Ledger midnight leather, brass wayfinder medallion, cyan illumination, and hare mark. The source is an opaque 1024-by-1024 square without pre-rendered rounded corners; the operating system owns the final home-screen mask.

## Primary navigation

The personal Wayfolio dock has exactly five positions:

1. Character
2. Pack
3. Live, represented by the raised central medallion
4. Journal
5. World

The permanent right quick rail and primary More destination are retired by this design. Their content moves into local tabs or the profile menu.

### Approved graphic families

The following asset families are approved for V1 packaging. Their raster files provide semantic artwork; selection, focus, pressed, disabled, badge, glow, pulse, loading, and reduced-motion states remain code-driven.

- **Group 1B primary navigation (WF-028):** Character, Pack, Live, Journal, World. Use only the approved v01 files registered in `Host/public/assets/approved/manifest.json`. Do not remap the retired Home / Guide / Journal / Map / More family. The approved Character asset is the final profile/cameo version; the earlier head-silhouette drafts are rejected. The approved World asset is the fantasy-world/astrolabe revision; the Earth-like globe draft is rejected.
- **Group 5 system and feature icons (WF-026):** Character, Abilities, Inventory, Crafting, Companion, People & Bonds, Quests, Connections, Wallet, Archive, Settings. Do not create icons merely to mirror every control.
- **Group 6 manifestation and notification assets (WF-027):** New Record, Record Updated, Warning, Connection Established, Item Received, Quest Update, Visual Generating / Loading. Use these modularly with projection behavior and dynamic text rather than generating a unique raster for every notification.

Approval of these graphic families allows packaging and semantic registration. It does not override the Stage 1 UI coding hold.

### Navigation behavior

- Each primary destination owns a navigation path and preserves it when another destination is opened.
- Tapping Live presents the current live state without discarding the prior destination.
- Tapping an already selected primary destination returns to that destination's root.
- Back affects only the active destination's path. It never disconnects a session or mutates gameplay.
- The dock remains stable across normal player screens.
- The Live medallion may glow or show a concise accessibility-labeled attention mark when player action is required.

## Routes

```text
Character
  Overview
  Abilities
  Equipment
  Magic and Traits

Pack
  All
  Gear
  Remedies
  Ingredients
  Quest Items
  Item Detail

Live
  Story or Dialogue
  Choice
  Free-form Response
  Response Submitted
  Waiting
  Dice Requested
  Private Result
  Encounter
  Loading / Disconnected / Error / Empty

Journal
  Notes
  Quests
  Sessions
  Note Detail / Editor
  Quest Detail
  Session Detail

World
  Map
  Places
  Creatures
  Botanicals
  Location Detail
  Creature Detail
  Botanical Detail

Profile Menu
  Profile
  Session
  Audio and Accessibility
  Settings
  DM Tools, DM authorization only
```

## Global components

### `WayfolioAppShell`

Owns safe-area layout, background layers, header, primary content, overlays, and bottom dock. It does not own campaign state.

### `WayfolioHeader`

- Leading control: contextual Back or decorative Wayfolio mark.
- Center: title and subtitle.
- Trailing control: profile menu.
- Minimum control target: 44 by 44 points.

### `WayfolioDock`

- Four peer destination buttons plus the raised Live medallion.
- Exactly one selected destination.
- Selected state uses label, icon, and luminance rather than color alone.
- The medallion must not overlap adjacent hit targets.

### `WayfolioProfileMenu`

Player rows: Profile, Session, Audio and Accessibility, Settings.

DM Tools is inserted only after DM authorization. It must not be rendered disabled or hidden behind opacity for ordinary players; it is absent from their menu model.

### `WayfolioLocalTabs`

Reusable horizontal local navigation. Supports three fixed tabs or horizontally scrolling category tabs. Tabs are presentation state and do not mutate campaign state.

### `WayfolioLedgerList` and `WayfolioLedgerRow`

Reusable for stats, equipment, inventory, notes, quests, sessions, places, creatures, and botanicals. Rows support optional approved artwork, title, known detail, value, state, and chevron.

### Item and equipment components

- `WayfolioItemListRow`: approved artwork, published name, category, known summary, optional published quantity, and detail chevron.
- `WayfolioEquipmentRow`: slot, published item name, known mechanical equivalence or field use, and optional status. It is descriptive until typed equipment intents exist.
- `WayfolioItemRecordView`: layered artwork, identity, published ownership and slot data, known use, and factual field note. Contextual mutation controls are rendered only when their typed intents are supplied.

### Creature components

- `WayfolioCreatureGridCard`: approved artwork, published name and descriptor, and authoritative observation completion.
- `WayfolioCreatureRecordView`: approved hero artwork, identity, observation progress, optional sound intent, and only the sections explicitly revealed by the authoritative creature record.
- Unrevealed creature sections are omitted from the view tree. The UI must not infer fields from completion percentage or reserve visible locked placeholders for them.

### Live components

- `WayfolioStoryPanel`
- `WayfolioSpeakerPanel`
- `WayfolioResponseComposer`
- `WayfolioVisibilitySelector`
- `WayfolioWaitingPanel`
- `WayfolioRollWaitingPanel`
- `WayfolioResultPanel`
- `WayfolioEncounterPanel`
- `WayfolioStatePanel`

## Screen contracts

### Character

Reads `GameSessionClient.CharacterSummary`. It may format values but must not calculate or persist character changes. Equipment shows the equipped loadout from the authoritative summary.

### Pack

Reads the existing inventory and equipment state. Initial implementation is display and inspection only. Equip, unequip, use, give, drop, craft, or split controls must not appear until the gameplay owner exposes typed intents and acknowledgements for them.

The Pack root presents the carried-item list with All, Gear, Remedies, Ingredients, and Quest Items filters. Selecting a row pushes Item Detail without changing inventory state. Equipment remains a Character local tab because it describes the active loadout; item records may be reached from either list when both refer to the same published item identity.

### Live

Reads scene, prompt, waiting, result, action, encounter, and connection state. It submits choices and responses through existing session methods. The screen does not determine success, failure, discovery, damage, inventory changes, or narrative consequences.

### Journal

Separates player-owned notes from host-published quests and session events. Player notes require an explicit persistence owner before editing is implemented. Private entries are never included in public shared-screen models.

### World

Shows only published map, place, creature, and botanical knowledge. Unknown fields are absent or explicitly unknown. Progressive creature discovery is driven by authoritative record completion and reveal fields.

The Creatures tab lists only creatures the player has observed or that the host has explicitly published to that player. Selecting a creature pushes Creature Detail. The detail screen renders a section only when the corresponding record field is revealed; observation completion is presentation metadata, not permission for the UI to calculate additional discoveries.

### List and detail presentation model

List and detail screens consume immutable presentation values derived from current session records:

- Item values: stable identifier, published name, category, known summary, approved artwork, optional quantity, optional owner, optional slot, optional status, known use, and field note.
- Equipment values: stable item identity, slot, published name, known equivalence or field use, approved artwork, and optional authoritative status.
- Creature values: stable identifier, published name, descriptor, approved artwork, authoritative observation completion, and an ordered collection of revealed sections.
- Contextual actions are capabilities supplied by the integration layer. A missing capability removes its control rather than disabling or simulating it.
- Selecting a list row is local navigation. It never changes inventory, equipment, discovery, or encounter state.

## Intent map

| Control | Intent owner | Existing contract |
|---|---|---|
| Primary dock, tabs, Back, profile menu | Local presentation | SwiftUI navigation state |
| Join session | Session | `GameSessionClient.connect(host:code:)` |
| Leave session | Session | `GameSessionClient.disconnect()` |
| Submit fixed choice | Session | `GameSessionClient.submitChoice(_:)` |
| Submit public/private response | Session | `GameSessionClient.submitAction(_:isPublic:)` |
| Digital shared roll | Host session | `roll_submit`, mode `digital` |
| Physical shared roll | Host session | `roll_submit`, mode `physical`, die 1 through 20 |
| Shared audio presentation | Presentation runtime | Existing `dm_presentation` and audio event contract |
| Item inspection | Local presentation | Existing published item data |
| Equip/use/give/drop/craft | Gameplay integration | Contract required before control appears |
| Note create/edit/delete | Persistence integration | Contract required before mutation appears |
| DM scene/dialogue/encounter controls | DM session | Existing host messages; typed Wayfolio DM client contract required |

## Shared iPad contracts

- Landscape 4:3 layout; no phone dock or profile controls.
- One speaker defaults left with words to the speaker's right.
- For two speakers, first is left and second is right.
- For three speakers, first is left, second is right, and third is center.
- Assigned positions remain stable during the scene.
- The active speaker receives emphasis; listeners remain visible but subdued.
- Player readiness may be public. Player-private response content is never public.
- The shared iPad owns current physical/digital roll selection and physical face entry.
- Public dice UI must not render the DM difficulty unless the authoritative event explicitly marks it public.

## Privacy requirements

- Authorization filters data before it reaches a view. Privacy must not depend on opacity, clipping, blur, or a covered layer.
- DM-only controls are absent from player route and menu models.
- Undiscovered creature, place, item, and quest fields are absent or represented as unknown.
- Progressive record views receive only player-visible fields; they never receive a complete DM record and attempt to conceal it locally.
- Private responses and private results remain on the submitting player's Wayfolio and authorized DM views.
- Shared presentation receives only published content.

## Layout and accessibility

- Personal Wayfolio is portrait-only during play.
- Shared iPad is landscape-only during play.
- Respect dynamic safe areas and keyboard avoidance.
- Minimum interactive target: 44 points.
- Essential information never relies on color alone.
- Support Dynamic Type without clipping critical controls.
- VoiceOver order follows header, current content, contextual actions, then dock.
- Waiting animations and dice effects support Reduce Motion.
- Decorative artwork is accessibility-hidden.

## Visual tokens

Reuse and refine the existing palette rather than replacing it:

- Midnight `#07101E`
- Navy `#0A1729`
- Raised navy `#10213A`
- Parchment `#E8D8B4`
- Deep parchment `#CDB889`
- Ink `#2A2015`
- Brass `#C99B4C`
- Bright brass `#F0C66D`
- Cyan `#6BE7FF`
- Violet `#A988FF`
- Magenta `#FF7BDE`
- Emerald `#73D79F`
- Danger `#FF6E7B`

Cyan is the default selected and active color. Violet, magenta, and emerald are reserved for semantic feature states and later skinning, not arbitrary decoration.

## Current-project migration

The implementation should refactor the existing shell in place:

- Replace `WayfolioSection.guide/entries/map/notes/more` with Character, Pack, Live, Journal, and World presentation destinations.
- Make Live the real center dock destination rather than overlaying the third peer tab.
- Remove the permanent `WayfolioQuickRail` from the shell after its destinations are represented in World local tabs or the profile menu.
- Move character content from `WayfinderSessionView` into Character.
- Move session connection controls from More into Profile > Session.
- Preserve `FieldGuideView`, `EntriesView`, `MapPlaceholderView`, notes work, `LivePlayView`, audio, persistence, and session behavior while re-homing their presentation.
- Do not create a replacement shell, project, session client, or audio system.

## Active-loadout presentation

The current SwiftUI shell exposes Equipment, Magic, Crafting, and Companions as local Character/Pack presentations within the approved five-destination shell.

- Equipment renders the approved full-body Renn reference between six presentation slots. The four published equipment records fill Armor, Primary Tool, Weapons, and Spellcasting Focus. Accessory and Field Utility are visual open-slot examples.
- Magic renders the two first-level spell-capacity places recorded in `Host/content/renn.json` and the currently published magic list. It does not claim that either slot is spent or ready because remaining-use state is not published to `GameSessionClient`.
- Crafting renders two visual project-capacity examples and reads carried tool names when available. No recipe is started and no inventory is consumed.
- Companions renders only host-confirmed active traveling assignments. `CreatureRecord.isCompanion` is not treated as authoritative active-travel state.
- Equipment presentation slots are isolated in `WayfolioEquipmentLayout`. They submit no intent and never write to session, creature, inventory, or persistence state.
- The refined implementation must replace these values with host-published equipment slots, spell-slot current and maximum values, crafting project capacity and assignments, companion capacity, active companion IDs, and per-creature slot cost.

## Known integration gaps

These do not block shell implementation, but affected mutation controls must wait:

1. Typed inventory mutation intents and acknowledgements are not exposed to SwiftUI.
2. Player-note persistence ownership is not finalized.
3. The Swift client does not yet expose an authorized DM role and typed DM controls.
4. The current shared host roll text includes DC unconditionally; the final public renderer needs an audience or visibility contract.
5. Live check request details available to the personal Wayfolio are currently limited; the UI must not invent missing skill, die, or modifier values.

## Implementation order

1. Update route and section types without deleting feature views.
2. Refactor the shell, header, dock, and profile overlay.
3. Re-home Character, Pack, Journal, and World read-only content.
4. Re-home session connection under Profile > Session.
5. Apply the new shell to Live and reuse existing prompt, response, waiting, result, and state components.
6. Update the shared iPad renderer to the approved 4:3 presentation hierarchy.
7. Wire only existing intents.
8. Add mutation controls only as their typed gameplay and persistence contracts become available.
9. Verify privacy, safe areas, orientation, Dynamic Type, VoiceOver, Reduce Motion, reconnect, and error states.

## Definition of implementation-ready

The UI may enter implementation when:

- the five-destination shell and profile menu are approved;
- the final visual skin direction is approved;
- global components and route ownership are agreed;
- every visible mutation control has an existing typed intent or is explicitly deferred;
- public and private render models exclude unauthorized data;
- the gameplay integration owner accepts the listed contract boundaries.
