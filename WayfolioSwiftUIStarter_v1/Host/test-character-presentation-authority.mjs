import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const character = await readFile(new URL('../Wayfolio/Features/Placeholders/MorePlaceholderView.swift', import.meta.url), 'utf8');
const sessionView = await readFile(new URL('../Wayfolio/Features/Session/WayfinderSessionView.swift', import.meta.url), 'utf8');
const sessionClient = await readFile(new URL('../Wayfolio/Session/GameSessionClient.swift', import.meta.url), 'utf8');
const live = await readFile(new URL('../Wayfolio/Features/Session/LivePlayView.swift', import.meta.url), 'utf8');
const imageStore = await readFile(new URL('../Wayfolio/Models/CharacterImageStore.swift', import.meta.url), 'utf8');

// Missing ability data must be omitted, while supplied values continue through to rendering.
for (const source of [character, sessionView]) {
  assert.doesNotMatch(source, /abilities\[key\]\s*\?\?\s*10/);
  assert.match(source, /abilityOrder\.compactMap/);
  assert.match(source, /character\.abilities\[key\]\.map/);
  assert.match(source, /ability\.score/);
}
assert.match(character, /if !availableAbilities\.isEmpty\s*\{\s*abilityCard\(availableAbilities\)/s);
assert.match(sessionView, /if !availableAbilities\.isEmpty\s*\{\s*abilitiesCard\(availableAbilities\)/s);

// Runtime character/equipment identity must never be manufactured as Renn Hazel.
assert.doesNotMatch(character, /\?\?\s*"Renn Hazel"/);
assert.doesNotMatch(sessionView, /\?\?\s*"Renn"/);
assert.match(character, /title:\s*character\.name/);
assert.match(character, /Equipment identity unavailable/);
assert.match(sessionView, /session\.character\?\.name\.trimmingCharacters/);

// Optional equipment metadata stays optional from decoding through presentation.
assert.match(sessionClient, /let qualityLevel:\s*Int\?/);
assert.match(sessionClient, /let family:\s*String\?/);
assert.doesNotMatch(sessionClient, /quality_level"\]\s*as\?\s*Int\s*\?\?\s*1/);
assert.doesNotMatch(sessionClient, /equipment_family"\]\s*as\?\s*String\s*\?\?\s*"Equipment"/);
assert.match(character, /guard let qualityLevel = item\.qualityLevel else \{ return item\.detail \}/);
assert.match(live, /guard let qualityLevel = item\.qualityLevel else \{ return item\.slot\.uppercased\(\) \}/);

// The local image store remains portrait-only and is not an equipment authority.
assert.doesNotMatch(imageStore, /\bequipment\b|\bloadout\b|\binventory\b|\bequipped\b/i);
assert.match(imageStore, /customImage\(for characterID:/);
assert.match(imageStore, /updateCrop\(characterID:/);

console.log('Character identity, ability, optional equipment metadata, and portrait-store authority contracts passed.');
