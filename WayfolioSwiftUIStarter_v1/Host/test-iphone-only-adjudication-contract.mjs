import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const session = await readFile(new URL('../Wayfolio/Session/GameSessionClient.swift', import.meta.url), 'utf8');
const live = await readFile(new URL('../Wayfolio/Features/Session/LivePlayView.swift', import.meta.url), 'utf8');
const surfaces = await readFile(new URL('../Wayfolio/DesignSystem/WayfolioSurfaces.swift', import.meta.url), 'utf8');

assert.match(session, /private func standaloneRuling\(for declaration: String\)/,
  'iPhone-only play must use an explicit standalone adjudication contract.');
assert.match(session, /guard consequential else \{[^]*requiresRoll: false/,
  'Routine declarations must have an automatic no-roll path.');
assert.match(session, /medicine \|\| animalHandling \|\| stealth \|\| perception \|\| physicalRisk \|\| socialRisk/,
  'Only meaningful uncertainty or consequence should promote a declaration to a roll.');
assert.match(session, /\\b\(calm\|soothe\|coax\|befriend\|restrain\|handle\|guide\)\\b/,
  'Animal Handling must require a meaningful handling action.');
assert.doesNotMatch(session, /\["calm", "soothe", "befriend", "animal", "creature", "slime"\]/,
  'Entity nouns alone must not promote a declaration to an Animal Handling check.');
assert.match(session, /prompt = standaloneFollowupPrompt\(afterCheck: false\)/,
  'Automatic actions must reopen Live for the next declaration.');
assert.match(session, /prompt = standaloneFollowupPrompt\(afterCheck: true\)/,
  'Resolved checks must reopen Live for the next declaration.');
assert.match(session, /notice = succeeded \? "An opening appears\. Continue the story\."/,
  'The post-check notice must use the computed success result.');
assert.doesNotMatch(session, /\bsucceded\b/,
  'The post-check path must not reference a misspelled, undefined success result.');
assert.match(session, /standaloneFailureNarration\(for skill: String\)/,
  'Failed checks must produce a fictional, forward-moving complication.');
const standaloneAction = session.match(/private func handleStandaloneAction\(_ text: String, isPublic: Bool, inputMode: String\) \{[^]*?\n    \}/)?.[0] ?? '';
assert.doesNotMatch(standaloneAction, /Nothing in the current situation makes the declared action uncertain enough|play continues without rolling/,
  'Visible no-roll narration must not explain adjudication machinery.');
assert.doesNotMatch(session, /The outcome is uncertain enough to call for a/,
  'Visible check-request narration must not redundantly explain the roll classification.');
assert.doesNotMatch(session, /attempt succeeds|attempt falls short/,
  'Post-check narration must remain fictional rather than announcing the adjudication result.');
assert.ok(session.includes('detail: "Rolled \\(natural) + \\(roll.modifier) = \\(total) against DC \\(roll.difficulty ?? 10)."'),
  'Roll and DC mechanics must remain in CheckResult.detail.');
assert.doesNotMatch(session, /The Creature Settles|The Metal Shifts/,
  'Standalone adjudication must not hard-code Pine Roots success/failure outcomes.');
assert.match(live, /if let prompt = session\.prompt \{/,
  'Live must show freeform prompts even when they contain no fixed choice buttons.');
assert.doesNotMatch(live, /if let prompt = session\.prompt, !prompt\.choices\.isEmpty/,
  'Live must not hide a valid freeform prompt just because it has no finite menu.');
assert.match(live, /voiceInput\.resetAfterSubmission\(\)[^]*actionText = ""[^]*composerExpanded = false[^]*composerFocused = false/,
  'Successful local submission must clear voice state, empty and collapse the composer, and dismiss focus.');
assert.match(live, /guard let self, self\.recognitionGeneration == generation else \{ return \}/,
  'Late callbacks from an invalidated recognition generation must not repopulate the composer.');
assert.match(live, /func resetAfterSubmission\(\) \{[^]*recognitionGeneration \+= 1[^]*transcript = ""/,
  'Submission must invalidate recognition and clear its prior transcript.');
assert.match(surfaces, /case \.dialogue: 0\.50/,
  'Dialogue panes must retain a dedicated but translucent midnight readability scrim.');
assert.match(surfaces, /\.fill\(\.ultraThinMaterial\)[^]*\.fill\(WayfolioPalette\.midnight\.opacity\(variant\.readabilityScrimOpacity\)\)/,
  'Dialogue glass must diffuse the environment before applying its readability tint.');

console.log('iPhone-only adjudication and continuation contract checks passed.');
