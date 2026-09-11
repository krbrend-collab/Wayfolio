#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const readinessPath = path.join(root, 'Specifications/UI/UI_ASSET_READINESS.json');
const checksumPath = path.join(root, 'Specifications/UI/UI_ASSET_CHECKSUMS.json');

const assets = [
  ['treetop_village', 'wayfolio_login_bg_01_treetop_village', '1qtkzW2Rp-pk-h7wxWHvkB7pb6u_zHE4d'],
  ['market_square', 'wayfolio_login_bg_02_market_square', '1TYhaYa_mkG4zkJfFASj54J8XACikeQCc'],
  ['mountain_shrine', 'wayfolio_login_bg_03_mountain_shrine', '1ZGa4UVHFOEvZ-ExT21pq_lrYoDikaR36'],
  ['harbor_village', 'wayfolio_login_bg_04_harbor_village', '1nneGfMFxeit2dgAdc7g0dXVE4P3avxnm'],
  ['desert_oasis', 'wayfolio_login_bg_05_desert_oasis', '1y8XSpOg9ExRZcTUhqFrk3n65RNBbC8Mp'],
  ['overgrown_ruins', 'wayfolio_login_bg_06_overgrown_ruins', '1BxN160a9rRvFywRvbVIyf_afanTBkaU0'],
  ['crystal_sanctuary', 'wayfolio_login_bg_07_crystal_sanctuary', '12zfDykpHPjzq6d7ZWhQCW5VTN_-njtue'],
  ['yokai_shrine_village', 'wayfolio_login_bg_08_yokai_shrine_village', '10X72N97Ikkz7CbprkqSVbkSeXLlaKVIs'],
  ['yokai_onsen', 'wayfolio_login_bg_09_yokai_onsen', '1tW7gGjcFiPf6McnfOKth1y6CJ5UVJ4rw'],
  ['bamboo_forest', 'wayfolio_login_bg_10_bamboo_forest', '1H0BET-0RyGe3agoeBH-3J2SYbh8qQ4oy'],
  ['redwood_forest', 'wayfolio_login_bg_11_redwood_forest', '1zHobwbFwIM0oJacs9PyC9btRGOVtdXLc'],
  ['autumn_forest', 'wayfolio_login_bg_12_autumn_forest', '1cP62Hf2iYNbL4IE4zxA92Y-GGBF5ZAhn'],
  ['dungeon_temple_hall', 'wayfolio_login_bg_13_dungeon_temple_hall', '1HgA2jQoosjk3fx_jJ42PWb1u8rhdm7Y7'],
  ['dungeon_crystal_temple', 'wayfolio_login_bg_14_dungeon_crystal_temple', '10ppgZYN7BzpWVGv0AXd_ccq4XSJxOIhH'],
  ['dungeon_crypt', 'wayfolio_login_bg_15_dungeon_crypt', '17nEHu4pxxNn4xRm-WawQcLtdtOLlaFuA'],
  ['crystal_cave', 'wayfolio_login_bg_16_crystal_cave', '1CAMimlsIFltPop1NmzpXMpej4PV6Pt0L']
];

const sha256 = data => crypto.createHash('sha256').update(data).digest('hex');
const readiness = JSON.parse(fs.readFileSync(readinessPath, 'utf8'));
const checksums = JSON.parse(fs.readFileSync(checksumPath, 'utf8'));

readiness.drive_metadata_verified_at = '2026-09-08';
readiness.broad_environment_scene_library.source_folder_or_manifest =
  'Google Drive folder 1OCy91HAdgK6SOAhlpaBHuBjzMXHhHXG8';
readiness.broad_environment_scene_library.registered_local_categories = assets.map(([category]) => category);
readiness.broad_environment_scene_library.bootstrap_candidates_needing_registry_mapping = [];
readiness.broad_environment_scene_library.readiness = 'approved_current_registered_locally';

const importedNames = new Set(assets.map(([, name]) => name));
checksums.assets = checksums.assets.filter(asset => !importedNames.has(asset.catalog_name));
for (const [, name, storageFileId] of assets) {
  const relativePath = `Wayfolio/Assets.xcassets/${name}.imageset/${name}.png`;
  const data = fs.readFileSync(path.join(root, relativePath));
  checksums.assets.push({
    catalog_name: name,
    path: relativePath,
    width: data.readUInt32BE(16),
    height: data.readUInt32BE(20),
    size_bytes: data.length,
    sha256: sha256(data),
    storage_file_id: storageFileId
  });
}
checksums.assets.sort((a, b) => a.catalog_name.localeCompare(b.catalog_name));

fs.writeFileSync(readinessPath, `${JSON.stringify(readiness, null, 2)}\n`);
fs.writeFileSync(checksumPath, `${JSON.stringify(checksums, null, 2)}\n`);
console.log(`Registered ${assets.length} approved scenic environment assets.`);
