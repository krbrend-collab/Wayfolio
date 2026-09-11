# Validation status

## Current local audit

- Native project version is build 130.
- The Wayfolio UI asset catalog has a machine-readable readiness inventory at `Specifications/UI/UI_ASSET_READINESS.json`.
- Run `node Tools/validate_ui_assets.mjs` from the project root to verify catalog references, dimensions, and approval-sensitive checksums for audited graphics.
- All 26 approved Group 7 spoiler-safe surfaces and all 16 approved scenic-environment categories are registered locally with recorded checksums, dimensions, and stable identifiers.
- The approved production-asset missing list is empty. The complete 81-image-set asset catalog passes integrity validation.
- Runtime navigation, projection, portrait, icon, start-surface, and environmental media candidates are registered as separate semantic assets rather than flattened runtime screens. Their catalog integrity is verified, but final visual authority remains chronology-first and must be bound to exact approval evidence.
- Build 130 completed a signed physical-device build on 2026-09-09, installed successfully on the connected iPad and Kevin's iPhone, and launched successfully on both.
- The WF-126–WF-130 convergence pass removes the obsolete iPhone perimeter, restores the header projection to a usable composition, applies the supplied header/dock geometry, moves shared cards to the audited translucent range, installs a full-width black five-position dock, and removes the permanent shared-iPad header/action form in favor of contextual overlays.
- The isolated gameplay suite passes persistent speaker assignment, restart restoration, progressive same-record discovery, shared-stage states, native-shell contracts, two-player privacy, player sovereignty, autosave, media integrity, and source-level JavaScript checks.

## Earlier completed checks

- Every Swift source file passes the Swift compiler's `-parse` grammar check.
- The project contains an Xcode project file, Info.plist, asset catalog, SwiftData model, navigation shell, and feature source tree.
- The app source is committed in a local Git repository.

## Remaining physical-device acceptance

The signed device build is no longer blocked by the unavailable simulator runtime. The following still require direct observation on unlocked physical devices:

- real Dynamic Island and bottom safe-area spacing
- accessibility at larger Dynamic Type sizes
- performance of map gestures on-device
- exact visual fidelity on the intended iPhone and iPad
- public/private paired-device routing with both devices connected
- explicit iPad Begin transition, shared-stage recovery, and live scene changes

The iPad and Kevin's iPhone are running build 130. Automatic signing includes Kevin's iPhone. Build 130 binds the user-supplied hardware header, five navigation icons, Manrope, and EB Garamond; expands the shell and projected background to full width; strengthens header and pane projection glow; and makes the selected peer destination rise while Live remains the fixed center medallion. Exact physical visual acceptance remains open until fresh screenshots are compared with the approved references.
