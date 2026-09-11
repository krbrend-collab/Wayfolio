import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const milestone = JSON.parse(await readFile(new URL('./content/renn-tutorial-milestone.json', import.meta.url), 'utf8'));
const launcher = await readFile(new URL('./public/launcher.html', import.meta.url), 'utf8');
const sharedRuntime = await readFile(new URL('./public/app.js', import.meta.url), 'utf8');
const server = await readFile(new URL('./server.mjs', import.meta.url), 'utf8');

assert.equal(milestone.representative_encounter.combat_required, false);
assert.equal(milestone.representative_encounter.prewritten_outcome, false);
assert.ok(milestone.representative_encounter.valid_approach_examples.includes('communicate'));
assert.ok(milestone.representative_encounter.valid_approach_examples.includes('free it from the metal'));
assert.deepEqual(milestone.party.map(member => member.id), ['renn','soren','lupin']);
assert.match(milestone.arrival_context, /Renn's words and decisions remain the player's/);

assert.match(launcher, /AI Storyteller spending limit/);
assert.match(launcher, /Reset AI Spending Counter/);
assert.match(launcher, /Estimated AI spend/);
assert.match(launcher, /Local Play — No AI Storyteller/);
assert.doesNotMatch(launcher.match(/<div class="ai-budget-panel">[\s\S]*?<\/div>\s*<\/div>/)?.[0] || '', /Low-cost gameplay mode/);
assert.match(sharedRuntime, /Live Storyteller paused — Local Play active\./);
assert.match(sharedRuntime, /setTimeout\(\(\) => \{ node\.hidden = true; \}, 4500\)/);

assert.match(server, /Only present companion IDs may speak/);
assert.match(server, /A creature encounter never requires combat/);
assert.match(server, /wayfolio_discovery_granted/);
assert.match(server, /session\.activeJourneyID !== 'renn-intro-tutorial'/);
assert.match(server, /resolution_kind \|\| ruling\?\.interpretation\?\.resolution\?\.kind/);

console.log('WF-015 wording, player sovereignty, companion continuity, progressive discovery, and open creature encounter fixture passed.');
