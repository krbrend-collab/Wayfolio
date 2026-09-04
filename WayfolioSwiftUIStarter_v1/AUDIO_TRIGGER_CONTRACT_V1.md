# Wayfolio Semantic Audio Trigger Contract — V1

Status: IMPLEMENTATION HANDOFF / PR #3
Cue coverage: 73 / 73 approved Audio Library Manifest entries

## Runtime rules

1. Audio is event-driven. The application must not require the player/DM to manually start ordinary music, ambience, gameplay SFX, Wayfolio manifestations, reveal stingers, or story stingers.
2. Consequential gameplay cues fire only after the authoritative state change is validated and committed. Narration alone never authorizes damage, healing, inventory, quest, knowledge, status, or other durable-state audio.
3. Audio events are presentation events. They never mutate campaign state.
4. Audience filtering occurs before delivery. Cue choice or timing must not leak GM-private or another player's private information.
5. Every remote/transient event must carry a stable event_id. Reconnects and retries must not replay an already-consumed event_id.
6. Transient events use a TTL. Expired events are discarded rather than replayed after reconnect.
7. Music and ambience are current-state projections, not queued events. A new music profile replaces the old music layer; a new ambience profile replaces the old ambience layer.
8. Normal baseline is one music layer plus one ambience layer, with transient SFX/stingers above them. Silence is valid.
9. Reveal stingers use first-meaningful-reveal semantics by entity unless the storyteller explicitly authors a later story beat with a different story cue.
10. The actual audio filename is resolved from the semantic ID. Story/runtime code must not hard-code filenames.

## Required event envelope for host/client transport

Minimum fields for remote audio presentation events:

- `event_id`: stable UUID/string used for dedupe
- `semantic_cue`: one of the 73 IDs below
- `audience`: DM private, one player/character, selected players, or shared public
- `created_at`: authoritative event time
- `ttl_seconds`: null only for current-state music/ambience/loops
- `source_revision` or equivalent authoritative state revision when the cue follows a durable change
- `entity_id` when a first-reveal rule applies

Clients must reject unknown semantic IDs, expired transient events, duplicates, and events outside their audience scope.

## 73-cue trigger map

### Music — 13

| Semantic ID | Trigger |
|---|---|
| `music.login_wayfolio` | Authenticated session + audio-ready handoff; once per session. |
| `music.location.safe_village` | Current scene resolves to safe-village music profile. |
| `music.location.market_shop` | Current scene resolves to market/shop music profile. |
| `music.location.tavern_inn` | Current scene resolves to tavern/inn music profile. |
| `music.location.wilderness_calm` | Current scene resolves to calm wilderness profile. |
| `music.location.water` | Current scene resolves to water/river/coast profile. |
| `music.location.sacred` | Current scene resolves to sacred/shrine profile. |
| `music.location.ruins_dungeon` | Current scene resolves to ruins/cave/dungeon exploration profile. |
| `music.location.hostile` | Current scene resolves to dangerous/hostile profile. |
| `music.state.safe_haven` | Scene enters safe-haven/rest state outside combat. |
| `music.story.reflection` | Storyteller marks a committed emotional/reflection beat. |
| `music.combat.standard` | Combat becomes active after initiative is committed and threat is not boss-tier. |
| `music.combat.boss` | Combat becomes active with boss/major-threat profile. |

### Ambience — 11

| Semantic ID | Trigger |
|---|---|
| `ambience.village.morning` | Village + morning ambience profile. |
| `ambience.village.evening` | Village + evening/night social ambience profile. |
| `ambience.market.crowd` | Market scene with active crowd ambience. |
| `ambience.tavern.room` | Tavern/inn interior ambience profile. |
| `ambience.forest.day` | Forest/wilderness + daytime ambience profile. |
| `ambience.forest.night` | Forest/wilderness + nighttime ambience profile. |
| `ambience.weather.rain` | Rain becomes the active weather ambience. |
| `ambience.water.stream` | Stream/river proximity becomes dominant ambience. |
| `ambience.cave.underground` | Cave/underground ambience profile. |
| `ambience.shrine.garden` | Shrine/garden ambience profile. |
| `ambience.campfire.night` | Camp/rest + night/campfire ambience profile. |

### Wayfolio system — 16

| Semantic ID | Trigger |
|---|---|
| `wayfolio.open` | Player opens an eligible personal Wayfolio record/pane/module. |
| `wayfolio.close` | Player closes/back-dismisses an eligible Wayfolio record/pane. |
| `wayfolio.select` | Player changes an eligible Wayfolio selection/navigation target. |
| `wayfolio.confirm` | Explicit player confirmation is accepted. |
| `wayfolio.login` | Authenticated Wayfolio login synchronization finishes. |
| `wayfolio.projection_appear` | Public projection/manifestation becomes visible. |
| `wayfolio.projection_dismiss` | Public projection/manifestation dismisses. |
| `wayfolio.new_record` | New player-legitimate knowledge record is durably committed. |
| `wayfolio.record_updated` | Existing legitimate record gains committed detail. |
| `wayfolio.quest_update` | Player-visible quest-state update is durably committed. |
| `wayfolio.item_received` | Item acquisition/transfer is durably committed. |
| `wayfolio.connection_established` | Compatible Link/Connection handshake reaches established state. |
| `wayfolio.warning` | A current player-visible warning becomes valid. |
| `wayfolio.visual_generating_start` | Approved live visual generation job starts. |
| `wayfolio.visual_generating_loop` | Visual generation remains active; stop on complete/fail/cancel. |
| `wayfolio.visual_generating_complete` | Generated visual is validated and available to intended audience. |

### Gameplay — 15

| Semantic ID | Trigger |
|---|---|
| `gameplay.dice_roll` | Digital die actually begins/commits a roll animation. |
| `gameplay.check_success` | Authoritative check result commits as success. |
| `gameplay.check_failure` | Authoritative check result commits as failure. |
| `gameplay.initiative_start` | Initiative order becomes authoritative and encounter begins. |
| `gameplay.turn_change` | Authoritative active combatant changes. |
| `gameplay.healing` | Positive HP/resource healing is durably committed. |
| `gameplay.damage` | Damage is durably committed. |
| `gameplay.status_positive` | Positive status/buff is durably applied. |
| `gameplay.status_negative` | Negative status/debuff is durably applied. |
| `gameplay.discovery` | Gameplay discovery becomes legitimate and committed. |
| `gameplay.objective_complete` | Objective completion is durably committed. |
| `gameplay.choice_appears` | Meaningful shared choice is presented and awaits players. |
| `gameplay.map_reveal` | New map/area information becomes legitimately visible. |
| `gameplay.story_discovery` | Story-level discovery becomes legitimate to current audience. |
| `gameplay.crafting_complete` | Crafting/alchemy result is durably committed for owning player. |

### Character / creature / threat reveals — 8

| Semantic ID | Trigger |
|---|---|
| `reveal.npc.friendly` | First meaningful reveal classified friendly/warm NPC. |
| `reveal.npc.mysterious` | First meaningful reveal classified mysterious NPC. |
| `reveal.creature.cute` | First meaningful reveal classified cute creature. |
| `reveal.creature.curiosity` | First meaningful reveal classified curious/whimsical creature. |
| `reveal.entity.majestic` | First meaningful reveal classified majestic entity. |
| `reveal.entity.uncanny` | First meaningful reveal classified uncanny/anomalous entity. |
| `reveal.threat.standard` | First meaningful reveal of a standard threat. |
| `reveal.threat.boss` | First meaningful reveal of a boss/major threat. |

### Story / location / transition — 10

| Semantic ID | Trigger |
|---|---|
| `story.location_arrival` | Party/current audience arrives at a meaningfully new location. |
| `story.location_departure` | Party/current audience leaves a meaningful location. |
| `story.landmark_discovery` | Landmark becomes legitimately discovered. |
| `story.scene_transition` | Story scene transition is committed. |
| `story.suspense_rise` | Storyteller marks a current suspense-escalation beat. |
| `story.danger_escalation` | Danger materially escalates in the current scene. |
| `story.revelation` | Major story revelation becomes legitimate to audience. |
| `story.resolution` | Meaningful story conflict/beat resolves. |
| `story.rest_camp` | Rest/camp state begins. |
| `story.quest_phase_change` | Quest phase transition is durably committed. |

## Replay / TTL defaults

- UI edge cues (`open`, `close`, `select`, `confirm`): 1–2 second TTL; do not queue.
- Dice/check/combat-turn transient cues: 3–5 second TTL.
- Knowledge/quest/item/reveal/story transient cues: 8–10 second TTL.
- Login cues: once per authenticated session; 15–30 second startup TTL.
- Music/ambience: current-state projection; no transient replay queue.
- Visual-generation loop: state loop; stop immediately on complete/fail/cancel.
- Reveal stingers: dedupe by entity + reveal milestone in addition to event_id.

## Device defaults

- Shared iPad: public music, ambience, gameplay SFX, reveal/stingers, story cues, shared manifestations.
- Personal iPhone: restrained Wayfolio UI cues and player-specific crafting/private cues.
- Mac host: authoritative event source and private diagnostics; normally not a duplicate public speaker.

## Acceptance tests before merge-to-production

1. Catalog contains exactly 73 semantic IDs and every ID resolves to exactly one approved canonical filename.
2. Unknown semantic ID safely no-ops/logs; it never crashes.
3. Missing audio bytes safely no-op/log until ingestion; no substitute sound is invented.
4. Same remote event_id delivered twice plays once.
5. Expired transient event does not play after reconnect.
6. Private event does not produce public iPad audio.
7. Healing/damage/check-result cues occur only after authoritative resolution commit.
8. New Record / Record Updated / Quest Update cues occur only after legitimate audience-filtered knowledge/state commit.
9. Standard music changes replace prior music rather than stack.
10. Ambience changes replace prior ambience rather than stack.
11. Reveal/story stinger ducks background audio and then restores it.
12. Boss combat replaces standard combat music and does not layer both.
13. Reconnect rebuilds current music/ambience from current scene state without replaying stale stingers.
14. Login cues fire once per session, not every view appearance.
15. Visual-generation loop stops on complete, failure, or cancellation.
16. Entity reveal does not replay its first-reveal stinger merely because a screen is reopened.
17. Xcode build passes on supported iPhone and iPad targets with actual bundled assets.
18. Physical-device test confirms shared/public cues do not duplicate across every player phone.

## Current implementation boundary

PR #3 currently provides the 73-ID app catalog, filename resolution, device-aware playback, music/ambience looping, transient playback, background ducking, local semantic trigger bridge, and initial UI trigger wiring.

The remaining host-side work requires the actual Mac/AI Storyteller runtime source plus Xcode/device validation. The host must emit the semantic IDs above from authoritative gameplay/story events rather than filenames. Source-byte ingestion remains separately required before audible playback can be validated.
