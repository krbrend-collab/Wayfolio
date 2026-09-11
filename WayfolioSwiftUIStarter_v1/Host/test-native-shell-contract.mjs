import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const route = await readFile(new URL('../Wayfolio/App/WayfolioRoute.swift', import.meta.url), 'utf8');
const dock = await readFile(new URL('../Wayfolio/Shell/WayfolioDock.swift', import.meta.url), 'utf8');
const header = await readFile(new URL('../Wayfolio/Shell/WayfolioHeader.swift', import.meta.url), 'utf8');
const shell = await readFile(new URL('../Wayfolio/Shell/WayfolioShell.swift', import.meta.url), 'utf8');
const surfaces = await readFile(new URL('../Wayfolio/DesignSystem/WayfolioSurfaces.swift', import.meta.url), 'utf8');
const live = await readFile(new URL('../Wayfolio/Features/Session/LivePlayView.swift', import.meta.url), 'utf8');
const root = await readFile(new URL('../Wayfolio/App/WayfolioRootView.swift', import.meta.url), 'utf8');
const metrics = await readFile(new URL('../Wayfolio/DesignSystem/WayfolioMetrics.swift', import.meta.url), 'utf8');
const personalPages = await readFile(new URL('../Wayfolio/Features/Placeholders/MorePlaceholderView.swift', import.meta.url), 'utf8');
const journal = await readFile(new URL('../Wayfolio/Features/Placeholders/NotesPlaceholderView.swift', import.meta.url), 'utf8');

for (const section of ['character', 'pack', 'live', 'journal', 'world']) {
  assert.match(route, new RegExp(`case ${section}\\b`), `missing ${section} destination`);
  assert.match(route, new RegExp(`wayfolio-nav-${section}`), `missing ${section} registered navigation art`);
}

assert.match(dock, /let sections = WayfolioSection\.allCases/);
assert.match(dock, /WayfolioDockBarShape\(notchCenterX: activeCenterX\)/);
assert.match(dock, /let isSelected = selected == section/);
assert.doesNotMatch(dock, /let isLive = section == \.live/);
assert.match(dock, /WayfolioPalette\.violet/);
assert.match(dock, /timingCurve\(0\.2, 0\.8, 0\.2, 1, duration: 0\.32\)/);
assert.match(header, /wayfolio-topbar-approved/);
assert.doesNotMatch(header, /wayfolio_header_projection_rail_v01/);
assert.match(header, /Color\.black/);
assert.match(shell, /ProjectedCanvasFrame\(\)/);
assert.match(metrics, /dockHeight: CGFloat = 122/);
assert.match(metrics, /dockGridHeight: CGFloat = 116/);
assert.match(metrics, /inactiveDockTarget: CGFloat = 54/);
assert.match(metrics, /activeDockMedallion: CGFloat = 78/);
assert.match(metrics, /activeDockIcon: CGFloat = 66/);
assert.match(metrics, /headerHardwareHeight: CGFloat = 74/);
assert.doesNotMatch(metrics, /headerContentStart/);
assert.match(surfaces, /struct ProjectionPane/);
assert.match(surfaces, /ultraThinMaterial/);
assert.match(surfaces, /violetGlass/);
assert.match(surfaces, /opacity\(0\.18\)/);

assert.match(live, /WayfolioDialogueCard/);
assert.match(live, /Declare an action/);
assert.match(live, /Private/);
assert.match(live, /Public/);
assert.match(live, /session\.playMode == \.iPhoneOnly/);

assert.match(root, /Button\("BEGIN SESSION"\)/);
assert.match(root, /beginSharedSession/);
assert.match(root, /entryPhase = \.gameplay/);
assert.match(root, /whiteOpacity/);
assert.match(root, /portalOpacity/);
for (const phase of ['firstFlash', 'dip', 'secondFlash', 'settle', 'ellipseMorph', 'gateway', 'accelerating', 'whiteout', 'gameplay']) {
  assert.match(root, new RegExp(`\\.${phase}\\b`), `missing shared entry phase ${phase}`);
}

assert.match(personalPages, /case quickAccess/);
assert.match(personalPages, /"Quick Access"/);
assert.doesNotMatch(personalPages, /case ready/);
assert.match(personalPages, /count: 4/);
assert.match(personalPages, /WayfolioFloatingItemDetail/);
assert.match(personalPages, /WayfolioStatChangeChips/);
assert.match(personalPages, /Label\("Use Item"/);
assert.match(journal, /ScrollView \{/);

console.log('Native moving shell, Character/Pack/Journal contracts, and explicit iPad Begin transition passed.');
