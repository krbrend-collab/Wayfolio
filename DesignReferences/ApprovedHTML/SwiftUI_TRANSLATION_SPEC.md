# Wayfolio iPhone SwiftUI Translation — Exact Source-Derived Reference

Date: 2026-09-09
Status: PROGRAMMED-REFERENCE EXTRACTION; NOT A SUBSTITUTE FOR THE THREE RAW HTML ORIGINALS

This document extracts values directly from the surviving File Library source text. It is safe to use as evidence of how the programmed snapshots behaved. It is **not** permission to override later explicit Design Chat visual decisions. Any value not exposed by the source is marked unresolved rather than estimated.

Source objects:
- `wayfolio_resolved_pages_approved_shell.html` — File Library `file_00000000170881fda2231d3245485590` — 2026-09-08T04:16:03Z
- `Wayfolio_World_Functional_Assessment_v10.html` — File Library `file_00000000c2908230b0d1f63b2d94afbc` — 2026-09-08T04:02:33Z
- `Wayfolio_Journal_Functional_Assessment_v01.html` — File Library `file_00000000b5988230977f2c6a0c3fc6d5` — 2026-09-07T07:01:47Z

## 1. Viewport and safe areas

### Resolved shell
- HTML viewport: `width=device-width,initial-scale=1,viewport-fit=cover`.
- `html,body`: width/height `100%`, margin `0`, overflow `hidden`.
- `.phone`: `width:min(430px,100vw)`; `height:100dvh`; `min-height:100vh`; `position:relative`; `overflow:hidden`; `isolation:isolate`.
- Reference maximum shell width is therefore 430 CSS px. No source-defined minimum width was found.
- No `env(safe-area-inset-*)` rule is present in the recovered resolved-shell source section. `viewport-fit=cover` is explicit; exact native safe-area offsets are not source-defined and must not be invented from screenshots.
- The HTML does not contain a source-enforced portrait-orientation lock. The geometry is portrait-oriented, but orientation enforcement is an app-level decision unless later authority specifies it.
- At `max-width:390px`, content-region horizontal inset changes from 12px to 10px, nav horizontal inset from 10px to 6px, labels from 13px to 12px, normal nav icon display size from 42px to 39px, and Live icon display size from 49px to 46px.

### World v10 / Journal v01 assessment frames
- Both use a 440×956 reference aspect ratio via `.stage { width:min(100%,440px); aspect-ratio:440/956; }`.
- At `max-width:520px`, stage width becomes `100%`, border radius becomes `0`, and box shadow is removed.
- These assessment frames are browser review wrappers, not an instruction to force a native iPhone to 440×956.

## 2. Background and complete shell layer intent

### Resolved shell environment
`.phone` uses CSS environment gradients rather than a source image:

```css
background:
  radial-gradient(ellipse 70% 40% at 15% 18%,rgba(108,177,119,.42),transparent 70%),
  radial-gradient(ellipse 66% 44% at 86% 44%,rgba(64,142,159,.31),transparent 72%),
  linear-gradient(160deg,#446154 0%,#284b4c 33%,#173944 67%,#0f2634 100%);
```

`.phone::before` adds:

```css
background:
  repeating-linear-gradient(96deg,transparent 0 46px,rgba(14,38,30,.10) 47px 55px,transparent 56px 102px),
  linear-gradient(to bottom,rgba(244,255,245,.06),transparent 22%,transparent 75%,rgba(0,0,0,.08));
opacity:.72;
```

The `html,body` background is `#071017`, but that is outside/behind `.phone`; it is not an opaque rectangle intended behind destination content.

### Black regions
Intentional opaque black in the resolved shell:
1. `.header-black`: full width, top `0`, height `80px`, `background:#000`.
2. `.camera-ellipse`: `222×69px`, centered, top `22px`, `background:#000`.
3. `.camera-ellipse::before`: inner black camera cutout `126×31px`, top `14px` inside ellipse.

The main `.content-region` is translucent. **No opaque black rectangle belongs behind the main scrolling Character / Pack / Live / Journal / World content in this source.**

### Back-to-front shell ordering visible in source
- `.phone` environment background.
- `.phone::before` environment/readability texture at z-index 0.
- `.content-region` z-index 6.
- destination `.page-screen` z-index 2 inside content region.
- `.content-region::after` edge-light overlay z-index 30 inside content region.
- `.approved-header` z-index 40.
- bottom navigation is a separate fixed shell layer above content; exact source uses a moving bubble/cutout treatment. Do not insert an opaque destination-content background between environment and content.

## 3. Top hardware bar — resolved shell programmed snapshot

Important authority note: the resolved shell renders its header in CSS. It does **not** reference the later final iPhone top-bar image binary. The exact final top-bar binary remains unresolved. Do not substitute the dated `wayfolio_header_projection_rail_v01.png`.

### Geometry
- `.approved-header`: left/right/top `0`; height `126px`; z-index `40`; pointer-events none.
- `.header-black`: height `80px`.
- `.header-black::after`: left/right `0`, bottom `-20px`, height `28px`; `linear-gradient(to bottom,#000 0 22%,rgba(0,0,0,.62) 46%,transparent 100%)`; opacity `.72`.
- `.camera-ellipse`: width `222px`, height `69px`, left `50%`, top `22px`, translated `-50%` X, fully rounded.
- camera inner black cutout: `126×31px`, top `14px`, horizontally centered.

### Orange/gold ellipse glow
```css
box-shadow:
  0 0 0 2px rgba(255,167,48,.88),
  0 0 7px 2px rgba(255,146,20,.30),
  0 0 20px 4px rgba(255,122,0,.15);
```

### Cyan emission under ellipse
- left/right `12%`, top `53px`, height `37px`.
- radial gradient at 50%/0%: rgba(91,232,255,.38) at 0%; `.21` at 26%; `.09` at 48%; transparent at 76%.
- `filter:blur(8px)`.

### Runtime text
Common `.header-runtime`:
- top `79px`, `translateY(-50%)`.
- family `Georgia,"Times New Roman",serif`.
- size `10px`; line-height `1`.
- color `#f3d892`.
- no explicit letter-spacing/weight declaration in the recovered rule.
- shadow: `0 0 .5px rgba(255,247,226,.90), 0 0 4px rgba(247,177,58,.22)`.

Left character runtime:
- `left:8%`; `width:29%`; overflow hidden; ellipsis.
- source content: `✦ Renn Hazel`.

Right weather runtime:
- `right:8%`; `width:31%`; `text-align:right`; overflow hidden; ellipsis.
- source content: `☀ Clear · Dusk`.

Connection indicator:
- center X `50%`; top `80px`; `5×5px` circle.
- fill `#75f0ff`.
- glow `0 0 5px #75f0ff, 0 0 10px rgba(117,240,255,.50)`.

No separate clock text is present in this resolved-shell header source. If native UI shows time separately, that comes from later authority, not this HTML snapshot.

## 4. Central projected content window

Resolved shell `.content-region`:
- left `12px`; right `12px`.
- top `104px`.
- bottom `139px`.
- z-index `6`.
- left keyline `1px solid rgba(143,238,251,.18)`.
- right keyline `1px solid rgba(143,238,251,.13)`.
- at <=390px: left/right `10px`.

Content scrim/projection field (`::before`):
```css
background:
  linear-gradient(180deg,rgba(6,41,53,.18),rgba(3,24,36,.14) 45%,rgba(2,20,31,.20)),
  radial-gradient(ellipse 90% 20% at 50% 0%,rgba(90,232,255,.08),transparent 70%);
box-shadow:inset 0 0 24px rgba(68,218,247,.025);
```

Vertical edge-light overlay (`::after`):
```css
background:
  linear-gradient(to bottom,
    rgba(226,253,255,.36),rgba(92,231,255,.10) 7%,transparent 15% 80%,
    rgba(255,218,132,.025) 90%,rgba(119,237,255,.12) 100%) left/1px 100% no-repeat,
  linear-gradient(to bottom,
    rgba(91,226,250,.18),transparent 19% 72%,rgba(217,252,255,.34) 90%,rgba(85,225,250,.16)) right/1px 100% no-repeat;
```

Destination mechanics:
- all five `.page-screen` elements occupy `inset:0` inside the single shared content region.
- only one is displayed at a time; default is Character.
- Character / Pack / Live / Journal / World use the same outer shell bounds in this source.
- `.page-screen` itself is `overflow:hidden`.
- inner `.scroll` is `height:100%; overflow-y:auto; overflow-x:hidden; padding:18px 15px 42px; overscroll-behavior:contain; -webkit-overflow-scrolling:touch`.
- scrollbar: `thin`, color `rgba(99,227,249,.35) transparent`.
- Character changes only inner scroll top padding to `14px`.

Native translation rule: content must begin at the source-defined content-region top rather than adding another large top spacer. The fixed outer content region already terminates `139px` above the bottom, so inner scrolling is the mechanism that prevents content from being covered by the dock. Do not add a second opaque or empty spacer layer above destination content.

## 5. Glass / projected panels

### Base projected pane — resolved shell
`.projected-pane`:
- position relative.
- border: `1px solid rgba(95,225,248,.16)`.
- background:
  - `radial-gradient(ellipse at 0% 0%,rgba(82,224,249,.10),transparent 42%)`
  - `linear-gradient(135deg,rgba(4,38,52,.50),rgba(3,23,35,.31))`
- box shadow: `0 0 12px rgba(62,215,245,.06), inset 0 0 18px rgba(61,205,236,.025)`.
- `backdrop-filter:blur(8px)` and `-webkit-backdrop-filter:blur(8px)`.
- radius `15px`.
- no source-defined saturation/brightness or blend-mode declaration in this base rule.
- background remains visible through the pane because all fills are translucent.

Base pane typography:
- `.pane-title`: `#94dfe9`, `8.5px`, uppercase, tracking `.15em`.
- `.pane-heading`: margin-top 4px; Georgia 400 `17px/1.1`, white.
- `.small-copy`: `#dcebee`, Georgia `11px/1.42`.
- `.tiny`: `9px`, `#9cc6cf`, line-height `1.35`.

### Character hero / identity pane
`.profile-head`:
- min-height `218px`; margin-top `9px`; radius `18px`.
- background `linear-gradient(180deg,rgba(7,35,46,.15),rgba(3,22,33,.42)), radial-gradient(circle at 74% 45%,rgba(95,229,255,.13),transparent 34%)`.
- border `1px solid rgba(105,228,246,.13)`.
- overflow visible.

Exact profile typography visible in source:
- profile name: Georgia 400 `29px/1`, white, margin-top 4px.
- profile metadata: `10px/1.45`, `#acd9df`, margin-top 6px.
- role text: Georgia `11.5px/1.43`, `#e7f3f4`, margin-top 12px.

### Journal shell — Journal v01 snapshot
- left/right `12px`; top `139px`; bottom `128px`.
- radius `21px`; overflow hidden; z-index 6.
- background gradients use translucent dark blue values; border `1px solid rgba(97,224,247,.15)`.
- shadow: `inset 0 0 24px rgba(57,203,237,.04), 0 0 4px rgba(62,218,247,.10)`.
- its `::before` draws separate top/bottom/left/right projected edge highlights, including cyan and small gold fragments, with `drop-shadow(0 0 2px rgba(116,239,255,.70)) drop-shadow(0 0 4px rgba(53,210,245,.20))`.

### Journal entry — Journal v01 snapshot
- margin bottom `9px`; padding `12px 13px`; radius `14px`.
- border `1px solid rgba(95,225,248,.15)`.
- translucent radial + dark-blue linear background.
- `::before` provides 1px top/bottom segmented cyan/gold edge highlights and a `0 0 3px rgba(66,217,247,.18)` drop shadow.
- entry metadata: `8.5px`, uppercase, tracking `.10em`, `#8fd2df`.
- entry title: `17px`, `#f8fcfd`.
- body: Georgia `11.5px/1.36`, `#d7e8ec`.

### Search / selected category controls
Journal v01 search:
- height `34px`; radius `11px`; horizontal padding `11px`.
- border `1px solid rgba(96,226,249,.22)`.
- background `linear-gradient(90deg,rgba(2,20,29,.30),rgba(2,16,24,.18))`.
- color `#9fc6d0`; size `10.5px`.

Journal category pill:
- min-height `28px`; horizontal padding `9px`; fully rounded.
- border `rgba(90,222,247,.17)`; background `rgba(6,35,47,.16)`; color `#c9e5ea`; size `9.5px`.
- selected: border `rgba(151,242,255,.62)`; text `#f2fdff`; shadow `0 0 7px rgba(76,226,255,.17)`; background `rgba(10,48,61,.29)`.

World v10 search:
- height `33px`; padding `0 10px`; radius `11px`.
- border `1px solid rgba(96,226,249,.20)`.
- background `linear-gradient(90deg,rgba(2,20,29,.28),rgba(2,16,24,.16))`.
- color `#a5cad2`; size `10px`.

World v10 category/place pill:
- min-height `27px`; padding `0 9px`; fully rounded.
- border `rgba(90,222,247,.15)`; background `rgba(6,35,47,.13)`; color `#cce6eb`; size `8.7px`.
- selected: text `#f4fdff`; border `rgba(151,242,255,.55)`; shadow `0 0 7px rgba(76,226,255,.15)`; background `rgba(10,48,61,.28)`.

### Not source-defined as reusable tokens
The three inspected snapshots do not expose one canonical token for every requested native component role. A universal exact token for `Stat pane`, `Inventory row`, `Live action composer`, `Disabled control`, and `Special manifestation state` has not been established from the currently exposed source segments. Do not manufacture those values by averaging other panels. Use destination-specific exact source rules once raw HTML is available, or later explicit Design Chat tokens.

## 6. Typography

### What these HTML snapshots actually use
Resolved shell global UI family:
`-apple-system,BlinkMacSystemFont,"SF Pro Display","Segoe UI",sans-serif`.

Resolved shell narrative/display serif:
`Georgia,"Times New Roman",serif`.

World v10 / Journal v01 global assessment UI family:
`system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif`.

World/Journal headings and long-form body use Georgia / Times New Roman in many rules.

### Resolved-shell semantic values exposed by source
- Screen title: Georgia 400, `31px/1.05`, white; margin top 4px; shadow `0 0 10px rgba(90,229,255,.09)`.
- Screen kicker: `9px/1`, uppercase, tracking `.19em`, `#9ce7f2`.
- Screen subtitle: Georgia `12px/1.42`, `#d1e5e9`, max-width `315px`.
- Pane title: `8.5px`, uppercase, tracking `.15em`, `#94dfe9`.
- Pane heading: Georgia 400 `17px/1.1`, white.
- Body/small copy: Georgia `11px/1.42`, `#dcebee`.
- Tiny metadata: `9px/1.35`, `#9cc6cf`.
- Header runtime: Georgia `10px/1`, `#f3d892`.
- Resolved-shell nav label snapshot: normal `13px/16px`, weight 500, `#667783`; selected label uses `#cfe5f4`, weight 650. <=390px label size is 12px.

### Manrope / EB Garamond / Andika
- The approved Wayfolio family pairing elsewhere in the design authority is **Manrope + EB Garamond**.
- These three HTML source snapshots do **not** package or identify the exact Manrope or EB Garamond binaries/PostScript names/weights.
- The exact canonical Manrope + EB Garamond package therefore remains blocking/unresolved.
- No recovered source evidence here establishes Andika as required by these snapshots.
- Do not substitute current downloaded font files and call them the approved original package.
- No Dynamic Type behavior is defined in HTML. Pixel font sizes are fixed; native Dynamic Type mapping requires a later/app-level accessibility specification.

## 7. Bottom navigation — two programmed snapshots must not be conflated

There is a source-level chronology/design conflict that must remain visible to Codex rather than silently reconciled.

### A. Resolved-shell moving bubble/cutout snapshot — 2026-09-08 04:16Z
The resolved shell uses one moving active bubble. Exact exposed values:
- regular bubble `76×76px`.
- Live-target bubble `84×84px`.
- bubble X centers: Character `10%`, Pack `30%`, Live `50%`, Journal `70%`, World `90%`.
- cutout translations: `0`, `82px`, `164px`, `246px`, `328px`.
- bubble transition: `left .30s cubic-bezier(.2,.8,.25,1), width .2s ease, height .2s ease`.
- bubble fill: `radial-gradient(circle at 50% 36%,#c3f6fb,#91e7f4 72%)`.
- bubble border: `1px solid rgba(255,255,255,.9)`.
- shadows: `0 3px 10px rgba(7,30,40,.13)`, cyan ring `0 0 0 3px rgba(115,226,241,.10)`, violet glows `0 0 14px rgba(208,177,255,.38)`, `0 0 26px rgba(187,142,255,.24)`, `0 0 38px rgba(164,120,255,.12)`.
- halo `::before`: inset `-9px`, radial ring with violet alpha values `.28/.18/.08`, blur `2px`.
- gold accent `::after`: `30×2px`, bottom `6px`, rgba(216,166,77,.58).
- active bubble image regular size `51×51px`, translated Y `3px`; Live bubble image `59×59px`.
- ordinary nav icon display size `42×42px`, inactive opacity `.68`; Live ordinary icon `49×49px`, translated Y `-5px`.
- selecting a destination hides that destination's ordinary icon via `opacity:0` and `translateY(-15px) scale(.72)` while displaying the corresponding icon in the moving bubble.
- selected label remains in the ordinary label position but changes color/weight to `#cfe5f4` / 650; it is not described by source as moving into the bubble.
- unselected label `#667783` / 500.
- reduced motion: all transitions and animations are disabled with `@media(prefers-reduced-motion:reduce){*{transition:none!important;animation:none!important}}`.

This implementation does **not** establish a separately permanent raised Live medallion while another destination is selected. The single bubble follows the selected destination. Live is larger only when Live itself is targeted.

### B. World v10 Figma-style notched dock snapshot — 2026-09-08 04:02Z
World v10 contains an explicit source comment:
`NEW LOWER MENU — Figma-style movable active bubble + notched bar ... In production the same notch/bubble shifts to the selected destination.`

Exact values:
- `.primary-dock`: left/right `4px`; bottom `0`; height `146px`; z-index `34`; filter `drop-shadow(0 -5px 16px rgba(50,201,232,.07))`.
- `.dock-shape`: bottom `0`, height `108px`.
- bar fill `rgba(3,20,30,.78)`; stroke `rgba(119,231,250,.19)`, width 1.
- bar edge stroke-width `1.15`, opacity `.74`.
- `.dock-grid`: bottom `4px`; height `138px`; five equal columns.
- unselected `.dock-item`: height `104px`; label color `#bdd6dc`; size `11.3px`; weight `520`; tracking `.012em`; shadow `0 1px 2px rgba(0,0,0,.42)`.
- unselected medallion `64×64px`, margin-bottom `2px`.
- unselected icon `64×64px`; opacity `.68`; filter `saturate(.82) brightness(.84) drop-shadow(0 0 2px rgba(73,212,241,.10))`.
- active item height `138px`.
- active medallion `86×86px`, `translateY(-19px)`, margin-bottom `-11px`.
- active medallion background ring has inset `-5px`, cyan border `rgba(122,232,250,.48)`, outer dark ring `0 0 0 5px rgba(2,17,27,.74)`, cyan glow `0 0 14px rgba(77,226,252,.30)`, inner `0 0 18px rgba(34,139,191,.19)`.
- active image `82×82px`, opacity `1`, saturation `1.06`, brightness `1.04`, cyan drop shadow `5px/.62`, gold drop shadow `9px/.20`.
- active label `#9ff2ff` with cyan glow `0 0 5px rgba(78,229,255,.24)`.
- medallion motion `0.32s cubic-bezier(.2,.8,.2,1)` for transform; width/height `.32s`.
- icon opacity/filter transition `.26s`; transform/size `.32s cubic-bezier(.2,.8,.2,1)`.
- source World v10 text states World is raised on that screen because World is selected; the same active socket is intended to shift to whichever destination is selected.

### Current-authority instruction
The resolved shell is timestamped later than World v10, but timestamp alone is not sufficient to determine current design authority. The latest explicit Design Chat approval/rejection must bind the desired dock treatment to an exact source/artifact. Until that is established, Codex must not silently merge the two navigation systems or infer a permanent-Live rule from either one.

### Icon binaries
The HTML embeds icon image data, but the exact raw HTML is not yet transferable and therefore the embedded image bytes cannot be exported/checksummed here. The resolved-shell embedded icons were previously identified as 220×220 PNG payloads. They are not byte-identical to the separate 1024×1024 V2 Drive files. `wayfolio_nav_character_v02.png` is explicitly dated/historical. Current exact individual icon binaries therefore remain an authority/recovery blocker.

### Hit targets / accessibility
- World v10 `.dock-item` structural height is 104px inactive / 138px active, but the source does not declare a separate semantic 44×44 accessibility hit rectangle.
- Resolved shell uses anchor elements with visible text labels Character / Pack / Live / Journal / World, but an exact per-item `aria-label` attribute has not been recovered from the currently exposed nav snippet.
- Native SwiftUI must add platform accessibility labels based on the five canonical destination names without pretending those labels came from a recovered HTML `aria-label` declaration.

## 8. World v10 exact behavior evidence useful to native translation

- Stage reference: 440×956.
- `.world-shell`: left/right `12px`, top `76px`, bottom `142px`, overflow hidden, z-index 6; translucent gradients and inset glow, no opaque black main-content fill.
- home views are mutually exclusive via radio state; selected detail record hides the category home view.
- map pan region: `inset:0 0 132px 0`, overflow auto in both axes, touch-action pan-x/pan-y, smooth scroll, scroll-padding `180px 125px 150px 125px`, hidden scrollbar.
- map space: `790×890px`; discovered region: left 58, top 54, 674×776 with irregular clip-path.
- screen title position: left 18px, top 48px, z-index 22.
- detail record scroll: absolute inset 0; padding `146px 16px 54px`; scroll-padding-top 146px; hidden scrollbar.
- record toolbar: absolute left/right 16px, top 88px, z-index 46; blur 8px; lower fade extends 20px with bottom -16px.
- shared list scroll: absolute inset 0; padding `52px 14px 148px`; hidden scrollbar.
- list card: margin-bottom 10px; padding 11px; radius 15px; border `rgba(97,225,248,.16)`; translucent dark-blue gradient; outer cyan glow 10px/.07; inset glow 16px/.025.

## 9. Journal v01 exact behavior evidence useful to native translation

- Stage reference: 440×956 with embedded PNG environment background and 9% black readability overlay.
- stage edge overlay: `linear-gradient(to bottom,rgba(0,0,0,.12),transparent 17%,transparent 85%,rgba(0,0,0,.17))`, z-index 50.
- haze: left/right -10%, top 112px, bottom 105px, blur 14px, opacity .78 with cyan radial/linear gradients.
- topbar: height 149px, z-index 24; embedded image stretches `width:100%;height:100%;object-fit:fill`.
- runtime text top 77px, Georgia 10px/1, color `#efd79c`; name left 11%/width28%; weather right9.6%/width31%.
- journal-shell left/right12, top139, bottom128, radius21.
- root/detail scrolls are one vertical scroller each; `height:100%`, overflow-y auto; no multiple independently scrolling columns.
- sticky tools are top 0, z-index10, blur8px.
- detail toolbar is sticky top0 z-index10.
- long-form detail is separate state; short/long content toggled through source radio state.

## 10. Blocking fields that must remain unresolved

Until the raw originals are transferable, do not claim exact values for:
- byte size or SHA-256 of any of the three HTML originals;
- exhaustive external/local dependency list and asset-path inventory;
- intrinsic pixel dimensions/checksums of every embedded data-URI asset;
- final approved top-bar image source/intrinsic dimensions/crop, because the later final binary is a separate unresolved authority;
- exact current individual Character/Pack/Live/Journal/World icon binaries;
- exact Manrope and EB Garamond package, PostScript names, versions, weights, filenames, or checksums;
- Andika requirement;
- source-defined Dynamic Type mapping;
- a canonical disabled-control token or special-manifestation token not present in the exposed source;
- app-level minimum/maximum supported iPhone dimensions beyond the source's 430px max shell width and <=390px media adjustment;
- exact iOS safe-area inset numbers; HTML uses `viewport-fit=cover` but no recovered `env(safe-area-inset-*)` rule.

## 11. Native SwiftUI translation rule

Implement mechanics from exact source values only where they are not superseded. Preserve these structural truths:
1. Environment/readability lives behind translucent projected content.
2. Opaque black is hardware framing, not a destination-content background.
3. Header and bottom navigation are fixed shell layers; destination content scrolls inside the bounded central projection region.
4. Destination screens share the shell rather than each inventing a new outer viewport.
5. Do not create extra top blank space; use the shell's content boundary as the starting frame.
6. Do not hide content under the dock; bound or pad the destination scroller to the shell's dock exclusion zone.
7. Do not infer current art authority from an embedded or versioned file without matching it to the latest explicit approval event.
8. If a source value is absent, leave it unresolved and return it to Design Chat rather than estimating from screenshots.
