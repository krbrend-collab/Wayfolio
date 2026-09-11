#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(toolDirectory, '..');
const catalogRoot = path.join(projectRoot, 'Wayfolio', 'Assets.xcassets');
const readinessPath = path.join(projectRoot, 'Specifications', 'UI', 'UI_ASSET_READINESS.json');
const readiness = JSON.parse(fs.readFileSync(readinessPath, 'utf8'));
const checksumPath = path.join(projectRoot, readiness.local_checksum_registry);
const checksumRegistry = JSON.parse(fs.readFileSync(checksumPath, 'utf8'));
const failures = [];
const notices = [];

function sha256(filePath) {
  return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

function pngDimensions(buffer) {
  if (buffer.length < 24 || buffer.toString('ascii', 1, 4) !== 'PNG') return null;
  return {width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20)};
}

function jpegDimensions(buffer) {
  if (buffer.length < 4 || buffer[0] !== 0xff || buffer[1] !== 0xd8) return null;
  let offset = 2;
  while (offset + 9 < buffer.length) {
    if (buffer[offset] !== 0xff) {
      offset += 1;
      continue;
    }
    const marker = buffer[offset + 1];
    if (marker === 0xd8 || marker === 0xd9) {
      offset += 2;
      continue;
    }
    const length = buffer.readUInt16BE(offset + 2);
    if (length < 2 || offset + length + 2 > buffer.length) break;
    if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker)) {
      return {width: buffer.readUInt16BE(offset + 7), height: buffer.readUInt16BE(offset + 5)};
    }
    offset += length + 2;
  }
  return null;
}

function imageDimensions(filePath) {
  const buffer = fs.readFileSync(filePath);
  return pngDimensions(buffer) ?? jpegDimensions(buffer);
}

for (const asset of readiness.verified_local_assets) {
  const filePath = path.join(projectRoot, asset.path);
  if (!fs.existsSync(filePath)) {
    failures.push(`${asset.asset_id}: missing ${asset.path}`);
    continue;
  }
  const dimensions = imageDimensions(filePath);
  if (!dimensions) {
    failures.push(`${asset.asset_id}: unsupported or unreadable image`);
  } else if (dimensions.width !== asset.width || dimensions.height !== asset.height) {
    failures.push(`${asset.asset_id}: expected ${asset.width}x${asset.height}, found ${dimensions.width}x${dimensions.height}`);
  }
  const actualHash = sha256(filePath);
  if (actualHash !== asset.sha256) {
    failures.push(`${asset.asset_id}: checksum changed; approval identity must be re-verified`);
  }
}

for (const asset of checksumRegistry.assets) {
  const filePath = path.join(projectRoot, asset.path);
  if (!fs.existsSync(filePath)) {
    failures.push(`${asset.catalog_name}: missing imported asset ${asset.path}`);
    continue;
  }
  const dimensions = imageDimensions(filePath);
  if (!dimensions || dimensions.width !== asset.width || dimensions.height !== asset.height) {
    failures.push(`${asset.catalog_name}: imported dimensions no longer match the checksum registry`);
  }
  if (sha256(filePath) !== asset.sha256) {
    failures.push(`${asset.catalog_name}: imported checksum changed; approval identity must be re-verified`);
  }
}

const imageSets = fs.readdirSync(catalogRoot, {withFileTypes: true})
  .filter(entry => entry.isDirectory() && entry.name.endsWith('.imageset'));

for (const imageSet of imageSets) {
  const directory = path.join(catalogRoot, imageSet.name);
  const contentsPath = path.join(directory, 'Contents.json');
  if (!fs.existsSync(contentsPath)) {
    failures.push(`${imageSet.name}: missing Contents.json`);
    continue;
  }
  const contents = JSON.parse(fs.readFileSync(contentsPath, 'utf8'));
  const filenames = (contents.images ?? []).map(image => image.filename).filter(Boolean);
  if (filenames.length === 0) failures.push(`${imageSet.name}: no raster file is registered`);
  for (const filename of filenames) {
    if (!fs.existsSync(path.join(directory, filename))) {
      failures.push(`${imageSet.name}: Contents.json references missing file ${filename}`);
    }
  }
}

for (const asset of readiness.approved_assets_missing_locally) {
  const imageSet = path.join(catalogRoot, `${asset.expected_catalog_name}.imageset`);
  if (fs.existsSync(imageSet)) {
    notices.push(`${asset.asset_id}: now present; verify checksum and approval, then move it into verified_local_assets`);
  }
}

const registeredSurfaces = readiness.approved_surface_library.registered_local_surface_themes.length;
const expectedSurfaces = readiness.approved_surface_library.approved_count;
const registeredEnvironments = readiness.broad_environment_scene_library.registered_local_categories.length;
const expectedEnvironments = readiness.broad_environment_scene_library.expected_categories.length;

console.log(`UI asset catalog: ${imageSets.length} image sets checked`);
console.log(`Approved surface library: ${registeredSurfaces}/${expectedSurfaces} assets registered locally`);
console.log(`Approved scenic environment registry: ${registeredEnvironments}/${expectedEnvironments} categories registered locally`);
console.log(`Approved production assets still listed as missing: ${readiness.approved_assets_missing_locally.length}`);
for (const notice of notices) console.log(`NOTICE: ${notice}`);

if (failures.length > 0) {
  for (const failure of failures) console.error(`FAIL: ${failure}`);
  process.exitCode = 1;
} else {
  console.log('UI ASSET INTEGRITY PASS — present audited files match their recorded dimensions and checksums.');
}
