# Wayfolio implementation plan

## Authority synchronized

This plan reflects the Wayfolio Development Sync through WF-130 and the current 2026-09-09 visual-authority correction, including:

- the official iPhone top-bar implementation specification;
- the approved and locked lower navigation authority;
- horizontal 4:3 detail-image preference where an approved asset exists;
- the Cooking + Alchemy V1 architecture;
- the cooking animation, sound, acquisition-time preparation, and runtime-performance rules.
- the approved iPad startup visual/audio/haptic sequence;
- the compiled iPhone start-screen menu overlay and broad-environment background system;
- explicit campaign, character, play-mode, Shared iPad, sync, checkpoint, location, settings, and resume interactions;
- the current device architecture: iPhone as required personal controller, Shared iPad as optional public/cinematic surface, and Mac as optional DM Studio rather than the gameplay host.

The live project remains authoritative. No older archive or ZIP should replace it.

## Completed through build 130

1. Reworked the lower navigation to the locked five-destination structure: Character, Pack, Live, Journal, World.
2. Removed the filled rectangular active-navigation treatment.
3. Added the selected circular opening, raised icon motion, cyan projection glow, and violet/lavender selected halo.
4. Honored Reduce Motion while retaining a clear selected state.
5. Added the official composite top-bar asset slot using the locked `wayfolio-topbar-approved` name.
6. Enforced the approved top-bar aspect ratio and pure-black fallback. No older projection artwork is substituted when the exact asset is absent.
7. The native project has advanced to build 130.
8. The persistent personal shell now follows the corrected WF-129 composition: no outer perimeter, black projector header, translucent projected panes, and a full-width black five-destination dock.
9. The shared iPad stage no longer reserves permanent space for the proof header or response form; dialogue, rolls, encounters, and results appear contextually over the scene.
8. Verified that the generic iPhone/iPad build product compiles.
9. Passed the isolated gameplay suite, two-player open-play turn, privacy, player sovereignty, per-character knowledge, restart autosave, F41 asset resolution, media integrity, and storyteller continuity tests.
10. Added separate Place record reading views that use a horizontal 4:3 presentation for the approved landscape artwork.
11. Registered all 26 surface assets, all 16 scenic-environment categories, and the seven formerly missing production identities; the 80-image-set integrity audit passes. Integrity and registration do not independently establish latest visual approval.
12. Added persistent per-speaker voice assignments with restart restoration and phone-only Wayfolio commentary routing in paired play.
13. Unified progressive campaign/player knowledge into stable records that enrich in place without duplicate discoveries.
14. Added the reusable shared-iPad exploration, manifestation, dialogue, result, reconnecting, and fallback stage states.
15. Added an explicit shared-iPad Begin gate and transition while preserving the five-destination personal Wayfolio shell and compact Live composer.
16. Applied the WF-130 shell geometry centrally: 129-point header region, 82-point black hardware field, 106-point content start, 146-point dock, 64-point inactive targets, 86-point active medallion, 82-point active icon, and the specified selected rise and timing curve.
17. Recorded the supplied Group 1D design-source identities in `Specifications/UI/IMPLEMENTATION_SOURCE_MAP.md`.
18. Corrected the dock hierarchy from physical-device evidence: Live remains the permanently raised 86-point central medallion while the selected peer destination uses luminance, halo, label, and icon state within its 64-point target.
19. Bound the supplied hardware header, five supplied navigation silhouettes, Manrope, and EB Garamond to the native target.
20. Corrected physical-device shell evidence by expanding the personal shell to the full display width, placing the environmental projection behind the content, strengthening pane/header glow, and raising selected peer destinations.

## Current asset status

The 26 Group 7 surfaces, 16 scenic-environment categories, runtime navigation candidates, projection rails, portraits, icons, and other named production assets are registered locally. The 81-image-set integrity audit reports no missing catalog files. Registration, filenames, checksums, and older manifest labels establish provenance—not proof that each visual is the latest approved art.

## Build 130 implementation status

The principal WF-129 convergence work is present and automated checks pass. Physical acceptance must not be reported as complete until both intended devices are exercised:

1. Build 130 passed the signed physical-device build, installed on the connected iPad and Kevin's iPhone, and launched successfully on both.
2. Automatic signing includes Kevin's iPhone. Five-destination physical visual acceptance remains open pending fresh build-130 screenshots.
3. Paired iPhone/iPad public/private routing, add/remove continuity, dialogue placement, and restart behavior pass automated fixtures but still require physical observation.
4. The recovered HTML authority remains a nonblocking archival-access item; current implementation authority is represented in the sync record, specifications, source, and fixtures.

## Priority implementation order

### P0 — tomorrow's physical-device proof

1. Add the connected iPhone to the development provisioning profile, then install build 126 or the next verified successor.
2. Confirm the iPhone top safe area is black and unobstructed on the real device.
3. Confirm all five lower-navigation destinations are reachable and the selected icon rises without clipping.
4. Confirm the iPad shared route joins the same journey as the iPhone.
5. Run one Renn public action, one private action, one digital roll, and one physical-roll submission.
6. Confirm the iPad only shows public information and the Mac DM view receives private information.
7. Pause and resume the journey, then restart the host and confirm the same state returns.

### P1 — current start and session architecture

1. Integrate the approved compiled iPhone menu overlay and choose its broad environment from authoritative campaign state.
2. Implement explicit campaign, player/character, and play-mode selectors using the approved projected-glass behavior.
3. Bind Shared iPad, campaign sync, checkpoint, location, settings, and Resume Session states to the runtime service.
4. Implement the approved iPad startup sound-and-haptic timeline alongside its visual transition.
5. Prove iPhone-only play and adding/removing the Shared iPad without restarting the journey.

### P2 — exact approved visual completion

1. Recover and bind the final full hardware composite and verified final navigation binaries to their latest explicit approvals; the registered header rail is historical/reference-only, Character V2 is dated, and the other V2 navigation files remain approval-unverified.
2. Deliver and register the approved Manrope and EB Garamond font binaries.
3. Perform an iPhone screenshot comparison for camera-zone clearance, centering, scale, and uncropped projection glow.
4. Review exact dock height, icon scale, halo, and rise distance on the real iPhone.
5. Calibrate pane radius, blur, tint, keyline, and glow from physical-device screenshots.
6. Verify the horizontal 4:3 Place detail presentation on iPhone and iPad while compact browsing remains efficient.

### P3 — Cooking + Alchemy functional foundation

1. Implement versioned content definitions and separate player-save records for ingredient knowledge, recipe knowledge, revealed effects, attempts, and provenance.
2. Implement capability-based tool matching shared across Cooking, Alchemy, and Herbalism.
3. Implement atomic draft/reserve/resolve/commit/rollback transactions.
4. Implement partial and content-incomplete recipe states without inventing missing canon.
5. Complete the Chamomile vertical-slice acceptance tests before adding presentation animation.

### P4 — Cooking presentation and media

1. Register the canonical technique vocabulary and `IMG_5443` fallback only after the corresponding approved optimized media is available.
2. Prepare and cache recipe presentation bundles when recipes are acquired, never when Cook is pressed.
3. Implement the native bottom-anchored presentation timeline, ingredient sequence, completion haptic, mechanical egg-timer cue, dish reveal, and exit.
4. Verify immediate response and local fallback behavior without a network request.

## Do not do yet

- Do not redraw the approved top bar from SwiftUI shapes.
- Do not substitute older projection references for the missing official composite asset.
- Do not create a sixth persistent Cooking or Alchemy navigation destination.
- Do not invent recipe quantities, effects, DCs, or undiscovered properties.
- Do not begin asset generation, download, extraction, or rendering when the player presses Cook.

## Tomorrow's evidence to capture

- iPhone screenshot: top bar and each selected lower-navigation destination.
- iPad screenshot: current public scene, public action, and roll result.
- Mac screenshot: private action receipt and journey controls.
- Build number shown in the installed app/Xcode run evidence.
- Pass/fail notes for action, roll, pause/resume, reconnect, and restart recovery.
