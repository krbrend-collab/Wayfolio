# Wayfolio Current Implementation Handoff

Inspection-only handoff generated from the repository at the current checkout. It does not represent the authoritative design specification; it records what is actually present.

## 1. Repository state

- Project: Wayfolio / `WayfolioSwiftUIStarter_v1`
- Branch: `feature/audio-architecture-foundation`
- Commit: `f62a731730faf9a892f4f28f58044816cb199dc5`
- Working tree: **dirty**; extensive tracked edits and untracked implementation files are present.
- Native framework: SwiftUI/UIKit, Swift, Xcode project (`Wayfolio.xcodeproj`).
- Host/runtime: Node.js ES modules, WebSocket (`ws`), QR code package.
- Targets: iPhone native shell, shared iPad native shell, central Node host/web UI.
- Build: `xcodebuild -project Wayfolio.xcodeproj -scheme Wayfolio -configuration Release`; Xcode Run targets `Kevin’s iPhone` or a simulator.
- Host start: `cd Host && npm start`.
- Host tests: `cd Host && npm test` (safe suite), plus the named scripts in `Host/package.json`.
- No dedicated Swift lint/typecheck configuration was found. Xcode is the native compiler/typechecker.
- No secrets or environment values are included here.

## 2. Project structure

Important native paths:

```text
Wayfolio/App/WayfolioRootView.swift       root, login/session shell, iPhone/iPad split
Wayfolio/App/WayfolioRoute.swift           WayfolioSection and route state
Wayfolio/Shell/WayfolioShell.swift         shared projected shell
Wayfolio/Shell/WayfolioDock.swift          persistent bottom navigation
Wayfolio/Shell/WayfolioHeader.swift        native header/top bar
Wayfolio/Shell/WayfolioQuickRail.swift     quick rail/secondary controls
Wayfolio/Features/Session/LivePlayView.swift
Wayfolio/Features/Session/WayfinderSessionView.swift
Wayfolio/Features/Placeholders/MorePlaceholderView.swift  Character/Pack/World views
Wayfolio/Features/Placeholders/NotesPlaceholderView.swift Journal
Wayfolio/Features/Placeholders/MapPlaceholderView.swift   World/map placeholder
Wayfolio/Features/Entries/EntriesView.swift
Wayfolio/Features/FieldGuide/FieldGuideView.swift
Wayfolio/Session/GameSessionClient.swift
Wayfolio/Presentation/PresentationRuntime.swift
Wayfolio/Models/SampleData.swift
Wayfolio/Models/CreatureRecord.swift
Wayfolio/Models/CharacterImageStore.swift
Wayfolio/DesignSystem/*
Wayfolio/Audio/*
Wayfolio/Assets.xcassets/*
```

Host paths:

```text
Host/server.mjs                         WebSocket/HTTP host
Host/session-runtime.mjs                 session lifecycle
Host/campaign-authority.mjs              campaign authority
Host/campaign-state-service.mjs          campaign persistence/state
Host/gameplay-interpreter.mjs            freeform action interpretation
Host/gameplay-policy.mjs                 reaction/navigation/affordance policy
Host/knowledge-records.mjs               filtered Journal knowledge records
Host/party-state.mjs                     party/player state
Host/storyteller-runtime.mjs             storyteller integration
Host/presentation-router.mjs             presentation events
Host/asset-resolver.mjs                  runtime asset resolution
Host/public/app.js, dm.html, review.html web/shared-table views
Host/test-*.mjs                          contract and integration tests
```

## 3. Current screen inventory

| Feature | Entry/path | Sources | Platform | Current state |
|---|---|---|---|---|
| Phone login/start | `phoneRoot` / `WayfolioPhoneLoginRoot` in `WayfolioRootView.swift` | `WayfolioRootView.swift`, assets | iPhone | Implemented, session-gated; state persisted in AppStorage |
| iPad start/session | `WayfolioIPadSharedRoot` | `WayfolioRootView.swift` | iPad/shared | Implemented/needs runtime review |
| Character Overview | `WayfolioSection.character` | `MorePlaceholderView.swift`, `WayfolioShell.swift` | iPhone | Implemented, bust-led character data and traits |
| Character Abilities | Character tab | `MorePlaceholderView.swift` | iPhone | Partial/static presentation |
| Character Equipment | Character tab | `MorePlaceholderView.swift`, `GameSessionClient.swift` | iPhone | Partial; equipment relationships are coordinated with host but visual review remains |
| Character Bonds/notes/traits | Character content | `MorePlaceholderView.swift`, `SampleData.swift` | iPhone | Partial/static mixture |
| Pack Carried/Quick Access/Materials | `WayfolioSection.pack` | `MorePlaceholderView.swift` | iPhone | Implemented-looking; data mixture and review needed |
| Item detail | `WayfolioRoute.item` | `WayfolioRootView.swift`, `MorePlaceholderView.swift` | iPhone | Implemented route, static/native detail |
| Live | `WayfolioSection.live` | `LivePlayView.swift`, `GameSessionClient.swift` | iPhone | Implemented typed flow; voice recognition needs physical-device review |
| Journal index/records | `WayfolioSection.journal` | `NotesPlaceholderView.swift`, `GameSessionClient.swift` | iPhone | Implemented-looking; knowledge filtering host-backed |
| Quests/recipes/cooking/crafting | Journal/Pack tabs | `NotesPlaceholderView.swift`, `MorePlaceholderView.swift` | iPhone | Partial/placeholder surfaces |
| World | `WayfolioSection.world` | `MapPlaceholderView.swift`, `FieldGuideView.swift` | iPhone | Held/placeholder map and field guide |
| Shared gameplay stage | iPad shared root | `WayfolioRootView.swift`, `Host/public/app.js` | iPad/web | Implemented presentation stage; needs native runtime review |
| Dialogue/presentation | host events + native session views | `PresentationRuntime.swift`, `presentation-router.mjs`, `app.js` | Cross-platform | Implemented in layers; exact authority boundary needs review |
| Manifestations/notifications | root overlays and host presentation events | `WayfolioRootView.swift`, assets, `PresentationRuntime.swift` | Cross-platform | Partial |

Screens not represented by a dedicated native route are explicitly **NOT IMPLEMENTED as independent native screens**; several are represented by placeholder/tab content.

## 4. Navigation architecture

`WayfolioSection` and `WayfolioNavigationState` live in `Wayfolio/App/WayfolioRoute.swift`. `WayfolioRootView` owns `@State navigation`; `currentNavigationStack` switches on `navigation.selectedSection`. Character, Pack, Journal, and World use `NavigationStack` and `WayfolioRoute` (`item`, `creature`); Live is a direct `LivePlayView` route. `WayfolioShell` renders the persistent header/content/dock. `WayfolioDock` sends a section callback to `WayfolioRootView.switchSection`. Back navigation pops the selected section’s stored path. Profile is a sheet. iPad uses a separate shared root/presentation path. There are currently two presentation/navigation worlds: the native SwiftUI shell and host web/shared-table presentation.

Known runtime concern: bottom dock touch feedback has been observed on physical iPhone without a visible section change; simulator review has changed sections successfully. This is **UNKNOWN — NEEDS RUNTIME REVIEW**, not resolved by this handoff.

## 5. State and data architecture

- Canonical host/session authority: `Host/campaign-authority.mjs`, `campaign-state-service.mjs`, `session-runtime.mjs`, `party-state.mjs`.
- Native connection/state projection: `Wayfolio/Session/GameSessionClient.swift`.
- Gameplay interpretation/policy: `Host/gameplay-interpreter.mjs`, `gameplay-policy.mjs`.
- Knowledge: `Host/knowledge-vault.mjs`, `knowledge-records.mjs`, `data/knowledge-vault.json`; filtered by audience/scope/relevance before delivery.
- Character/equipment: native `SampleData.swift` and `MorePlaceholderView.swift` plus host equipment/party state. This is a mixed source of truth and needs reviewer reconciliation.
- Journal: native records display projected `GameSessionClient` data and host knowledge records.
- Dialogue/presentation: host `presentation-router.mjs`/`presentation-runtime` and native `PresentationRuntime.swift`/event channel.
- Audio/voice: native `Audio/*`, `PresentationAudioCoordinator.swift`, host `audio.js`, voice profiles and audio director tests.
- Persistence: host JSON data under `Host/data` and content files; native AppStorage for phone session host/code/active state.
- Multiplayer/iPhone↔iPad: WebSocket/presentation transport and session runtime are present; native device synchronization still needs runtime review.

Duplicate/mock risk: native feature surfaces contain sample/static data while host authority contains richer campaign state; the handoff reviewer should not assume all native cards are authoritative.

## 6. iPhone versus shared iPad

The iPhone exposes personal Character, Pack, Live, Journal, and World functions through the persistent shell and can hold private/session state. The iPad root is a shared presentation surface for start/session, party, dialogue, scene, NPC/character staging, public results, and manifestations. Code separation exists, but shared/native presentation and personal state boundaries require runtime review.

## 7. Dialogue and character presentation

Native dialogue/session presentation is primarily in `LivePlayView.swift`, `WayfinderSessionView.swift`, `PresentationRuntime.swift`, and `PresentationEvent*.swift`. Host dialogue/presentation is in `server.mjs`, `presentation-router.mjs`, `public/app.js`, `public/dm.html`, and character voice profiles. Character asset selection is distributed between `CharacterImageStore.swift`, `asset-resolver.mjs`, content manifests, and view-specific asset names. Bust/portrait and full-body equipment contexts are not centralized in one resolver; fallback behavior is asset-name/placeholder dependent. Speaker slot, active speaker, narration, expression, and transition behavior are more complete in host presentation than in the native personal shell and should be reconciled against the authoritative spec.

## 8. Asset system

Native image assets are in `Wayfolio/Assets.xcassets`, including built/fallback backgrounds, navigation icons, character/creature images, topbar/rail art, login art, and manifestation art. Runtime host assets are described by `Host/data/drive-asset-manifest-lkg.json`, `asset-resolver.mjs`, and `content/premade-asset-sources.json`. Actual Wayfolio art and fallback/placeholder art are intentionally mixed in the catalog. Hard-coded asset names remain in Swift views and host content. `CharacterImageStore.swift` and host asset resolver are the key review points.

## 9. Visual system/shared components

`WayfolioPalette.swift`, `WayfolioTypography.swift`, and `WayfolioMetrics.swift` define semantic colors, fonts, spacing, radii, and dock/header measurements. `WayfolioSurfaces.swift` and `ChromaGlow.swift` provide projected/glass surfaces and glow effects. `WayfolioFilterChip.swift`, `EntryCard.swift`, `WayfolioProgressStrip.swift`, `WayfolioDock.swift`, `WayfolioHeader.swift`, and `WayfolioQuickRail.swift` are reusable shell components. Accessibility labels/traits exist on the dock and many controls; physical-device accessibility/hit-testing remains unverified. Cyan/gold/violet treatments are implemented in the native shell and host CSS, but not yet proven identical across platforms.

## 10. Issues visible from code

| Severity | Affected files | Evidence / runtime visibility |
|---|---|---|
| Blocking | `WayfolioDock.swift`, `WayfolioRootView.swift` | Physical iPhone reportedly receives dock touches but does not change section; simulator changes successfully. Runtime-visible. |
| Major | `MorePlaceholderView.swift`, `SampleData.swift`, host campaign state | Native feature cards and host authority are mixed; possible duplicate sources of truth. Runtime-visible depending on session. |
| Major | `WayfolioRootView.swift`, `WayfolioShell.swift`, host web presentation | Native and host presentation/navigation systems coexist; synchronization boundaries require review. |
| Major | `CharacterImageStore.swift`, `asset-resolver.mjs`, feature views | Asset selection is distributed; bust/full-body and fallback rules are not centralized. |
| Moderate | `NotesPlaceholderView.swift`, host knowledge files | Journal UI and knowledge authority are separate layers; relevance/audience behavior needs device/session review. |
| Moderate | `MapPlaceholderView.swift` | World remains visually held/placeholder by design. |
| Moderate | `LivePlayView.swift`, speech recognition code | Native speech recognition has been validated only partially; simulator reports recognizer initialization failure and physical permission flow needs review. |
| Minor | `WayfolioDock.swift` | Recent hit-target code has device-specific opacity/frame workarounds and needs cleanup after behavior is understood. |

## 11. Tests and verification

Host unit/contract/integration coverage is extensive under `Host/test-*.mjs`, including policy, knowledge, equipment, session mode, storyteller, audio, privacy, party state, reconnect, two-player, media, native-shell, and shared-stage contracts. There are no native Swift unit/UI snapshot suites visible in the repository. Accessibility is represented by code labels/traits but has no automated test suite. Recent safe host suites and focused policy/contract checks have passed during development. Full Xcode builds have been environment-sensitive: the Swift compile reached the modified code, while simulator packaging has failed when CoreSimulator reported no available runtime; the physical Xcode target has had a separate dock runtime issue. Therefore current overall build/test status is **not VERIFIED**.

## 12. Recent implementation history

Recent commits most relevant to understanding the current runtime are:

- `f62a731` Queue stable NPC arrivals and dialogue
- `a75ab2a` Define stable NPC presentation profiles
- `494a299` Trigger audio director from live play context
- `35eae69` Define conservative live audio director rules
- `1e9394c` Route movement and scene transition audio
- `e9b7f38` Add movement and scene transition sound library
- `12fb4fe` Route semantic spell audio families
- `e22ec4a` Add distinct spell family sounds

The working tree also contains the current WF-141/WF-143/WF-144 implementation pass and substantial native shell/host edits not yet committed in the inspected checkout.

## 13. Implementation status matrix

| Area | Status |
|---|---|
| Login / Start | PARTIAL |
| Account flow | NOT IMPLEMENTED |
| Session/device-mode selection | PARTIAL |
| iPhone persistent shell | IMPLEMENTED — NEEDS RUNTIME REVIEW |
| Bottom navigation | UNKNOWN — NEEDS RUNTIME REVIEW |
| Character Overview | IMPLEMENTED — NEEDS REVIEW |
| Character Abilities | PARTIAL |
| Character Equipment | PARTIAL |
| Character Bonds | PARTIAL |
| Character Notes/Traits | PARTIAL |
| Pack — Carried | IMPLEMENTED — NEEDS REVIEW |
| Pack — Quick Access | PARTIAL |
| Pack — Materials | PARTIAL |
| Item Detail | PARTIAL |
| Live | IMPLEMENTED — NEEDS REVIEW |
| Journal index | IMPLEMENTED — NEEDS REVIEW |
| Journal record detail | PARTIAL |
| Quest List / Detail | PARTIAL |
| Recipes / Cooking | PARTIAL |
| Crafting / Alchemy | PARTIAL |
| World | LEGACY / POSSIBLY SUPERSEDED |
| World Map / Travel | PLACEHOLDER |
| Shared iPad Start | IMPLEMENTED — NEEDS REVIEW |
| Shared iPad Gameplay Stage | IMPLEMENTED — NEEDS REVIEW |
| Dialogue pane | PARTIAL |
| Speaker portraits | PARTIAL |
| Expression system | PARTIAL |
| Public checks/results | IMPLEMENTED in host; NEEDS REVIEW native |
| Media reveals | PARTIAL |
| Manifestations | PARTIAL |
| Audio/voice | PARTIAL |
| iPhone/iPad synchronization | PARTIAL |
| Offline/reconnect/error handling | PARTIAL |
| Accessibility | PARTIAL |

## 14. Files the reviewer should inspect first

1. `Wayfolio/App/WayfolioRootView.swift`
2. `Wayfolio/App/WayfolioRoute.swift`
3. `Wayfolio/Shell/WayfolioShell.swift`
4. `Wayfolio/Shell/WayfolioDock.swift`
5. `Wayfolio/Shell/WayfolioHeader.swift`
6. `Wayfolio/Features/Session/LivePlayView.swift`
7. `Wayfolio/Features/Session/WayfinderSessionView.swift`
8. `Wayfolio/Features/Placeholders/MorePlaceholderView.swift`
9. `Wayfolio/Features/Placeholders/NotesPlaceholderView.swift`
10. `Wayfolio/Features/Placeholders/MapPlaceholderView.swift`
11. `Wayfolio/Session/GameSessionClient.swift`
12. `Wayfolio/Presentation/PresentationRuntime.swift`
13. `Wayfolio/Presentation/WebSocketPresentationTransport.swift`
14. `Wayfolio/Models/CharacterImageStore.swift`
15. `Wayfolio/Models/SampleData.swift`
16. `Wayfolio/DesignSystem/WayfolioMetrics.swift`
17. `Wayfolio/DesignSystem/WayfolioSurfaces.swift`
18. `Wayfolio/DesignSystem/WayfolioTypography.swift`
19. `Host/server.mjs`
20. `Host/session-runtime.mjs`
21. `Host/campaign-authority.mjs`
22. `Host/campaign-state-service.mjs`
23. `Host/gameplay-interpreter.mjs`
24. `Host/gameplay-policy.mjs`
25. `Host/knowledge-records.mjs`
26. `Host/presentation-router.mjs`
27. `Host/asset-resolver.mjs`
28. `Host/public/app.js`
29. `Host/public/style.css`
30. `Host/test-safe-suite.mjs`

## 15. Handoff boundary

This document is an implementation inventory only. It intentionally does not resolve conflicts with authoritative Wayfolio design/gameplay documents, and it does not claim any item VERIFIED or COMPLETE. The next reviewer should compare this inventory against the current Sync Doc and durable design authority before changing code.
