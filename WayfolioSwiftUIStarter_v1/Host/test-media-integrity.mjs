import {access, readFile} from 'node:fs/promises';
import {join} from 'node:path';

const root = new URL('.', import.meta.url).pathname;
const specs = join(root, '..', 'Specifications', 'Audio');
const media = join(root, '..', 'Wayfolio', 'Resources');
const catalog = JSON.parse(await readFile(join(specs, 'AudioCueCatalog.json'), 'utf8'));
const locations = JSON.parse(await readFile(join(specs, 'LocationAmbienceProfiles.json'), 'utf8'));
const cueIDs = new Set(catalog.cues.map(cue => cue.id));
const missingFiles = [];
for (const cue of catalog.cues) {
  try { await access(join(media, cue.file)); } catch { missingFiles.push(`${cue.id}: ${cue.file}`); }
}
const missingReferences = [];
for (const [profileID, profile] of Object.entries(locations.profiles)) {
  for (const cue of [profile.base_cue, profile.music?.cue, ...(profile.details || []).map(detail => detail.cue)].filter(Boolean)) {
    if (!cueIDs.has(cue)) missingReferences.push(`${profileID}: ${cue}`);
  }
}
if (missingFiles.length || missingReferences.length) {
  throw new Error(`Media integrity failed. Missing files: ${missingFiles.join(', ') || 'none'}. Missing references: ${missingReferences.join(', ') || 'none'}.`);
}
console.log(`Media integrity passed: ${catalog.cues.length} cues and ${Object.keys(locations.profiles).length} location sound profiles.`);
