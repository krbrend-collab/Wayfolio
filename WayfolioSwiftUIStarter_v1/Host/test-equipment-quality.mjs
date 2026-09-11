import assert from 'node:assert/strict';
import {normalizeEquipment, normalizeQualityLevel, validateEquipment} from './equipment-quality.mjs';

assert.equal(normalizeQualityLevel(undefined),1);
assert.equal(normalizeQualityLevel(5),5);
assert.equal(normalizeQualityLevel(9),5);
assert.equal(normalizeQualityLevel(2.5),1);

const legacy = normalizeEquipment([{slot:'Armor',name:'Travel leathers',detail:'Weathered.'},
  {slot:'Hand',name:'Staff',detail:'Ring-headed.',qualityLevel:3}]);
assert.equal(legacy[0].slot,'Protective Gear');
assert.equal(legacy[0].equipment_family,'Protective Gear');
assert.equal(legacy[0].quality_level,1);
assert.equal(legacy[1].quality_level,3);
assert.equal(validateEquipment(legacy).valid,true);

const roundTrip = JSON.parse(JSON.stringify(legacy));
assert.deepEqual(normalizeEquipment(roundTrip),legacy);
console.log('Equipment quality levels 1-5, Protective Gear terminology, legacy defaults, and round-trip preservation passed.');
