import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const session = await readFile(new URL('../Wayfolio/Session/GameSessionClient.swift', import.meta.url), 'utf8');
const live = await readFile(new URL('../Wayfolio/Features/Session/LivePlayView.swift', import.meta.url), 'utf8');

assert.match(session, /private func standaloneRuling\(for declaration: String\)/,
  'iPhone-only play must use an explicit standalone adjudication contract.');
assert.match(session, /guard consequential else \{[^]*requiresRoll: false/,
  'Routine declarations must have an automatic no-roll path.');
assert.match(session, /medicine \|\| animalHandling \|\| stealth \|\| perception \|\| physicalRisk \|\| socialRisk/,
  'Only meaningful uncertainty or consequence should promote a declaration to a roll.');
assert.match(session, /prompt = standaloneFollowupPrompt\(afterCheck: false\)/,
  'Automatic actions must reopen Live for the next declaration.');
assert.match(session, /prompt = standaloneFollowupPrompt\(afterCheck: true\)/,
  'Resolved checks must reopen Live for the next declaration.');
assert.match(session, /notice = succeeded \? "The check resolved\. Continue the story\."/,
  'The post-check notice must use the computed success result.');
assert.doesNotMatch(session, /\bsucceded\b/,
  'The post-check path must not reference a misspelled, undefined success result.');
assert.match(session, /The failure changes the situation rather than ending play/,
  'Failed checks must explicitly preserve forward progress.');
assert.doesNotMatch(session, /The Creature Settles|The Metal Shifts/,
  'Standalone adjudication must not hard-code Pine Roots success/failure outcomes.');
assert.match(live, /if let prompt = session\.prompt \{/,
  'Live must show freeform prompts even when they contain no fixed choice buttons.');
assert.doesNotMatch(live, /if let prompt = session\.prompt, !prompt\.choices\.isEmpty/,
  'Live must not hide a valid freeform prompt just because it has no finite menu.');

console.log('iPhone-only adjudication and continuation contract checks passed.');
