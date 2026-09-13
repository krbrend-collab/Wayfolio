import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const session = await readFile(new URL('../Wayfolio/Session/GameSessionClient.swift', import.meta.url), 'utf8');
const surfaces = await readFile(new URL('../Wayfolio/DesignSystem/WayfolioSurfaces.swift', import.meta.url), 'utf8');

const submitRoll = session.match(/private func submitRoll\(mode: String, dice: \[Int\]\) \{[^]*?\n    \}/)?.[0] ?? '';
assert.match(submitRoll, /if isStandaloneSession \{[^]*resolveStandaloneRoll\(mode == "digital" \? \[\] : dice\)[^]*return[^]*guard let pendingRoll, pendingRoll\.playerID == playerID/,
  'Phone-owned rolls must reach the standalone resolver before shared-session identity validation.');

const resolver = session.match(/private func resolveStandaloneRoll\(_ dice: \[Int\]\) \{[^]*?\n    \}/)?.[0] ?? '';
assert.match(resolver, /guard !isResolvingStandaloneRoll else \{ return \}/,
  'Standalone roll resolution must reject reentrant/double submissions.');
assert.match(resolver, /pendingRoll = nil[^]*awaitingSharedRoll = false[^]*checkResult = CheckResult[^]*appendCompletedStoryBeat[^]*persistStandaloneSnapshot\(\)/,
  'The canonical resolver must clear roll state, create a result and story beat, and persist it.');

assert.match(session, /currentStandaloneSnapshotSchemaVersion = 2/,
  'The standalone snapshot must carry the targeted history-migration revision.');
assert.match(session, /removingObsoleteStandaloneNarration\(from:/,
  'Restoration must migrate obsolete fixture narration rather than deleting all history.');
assert.match(session, /retainedSegments\.isEmpty else \{ return nil \}/,
  'Only beats emptied by the targeted narration filter may be removed.');

assert.match(surfaces, /case \.dialogue: 0\.50/,
  'Dialogue tint must remain translucent enough for environmental connection.');
assert.match(surfaces, /var materialOpacity: Double \{ self == \.dialogue \? 0\.62 : 0\.22 \}/,
  'Dialogue surfaces must receive stronger material diffusion without changing other panes.');

console.log('Standalone physical-device repair contract checks passed.');
