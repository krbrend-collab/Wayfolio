function text(value, fallback = '') { return typeof value === 'string' && value.trim() ? value.trim() : fallback; }

export function normalizeQualityLevel(value, fallback = 1) {
  const supplied = Number(value); const safeFallback = Math.max(1, Math.min(5, Number(fallback) || 1));
  return Number.isInteger(supplied) ? Math.max(1, Math.min(5, supplied)) : safeFallback;
}

export function normalizeEquipment(items) {
  return (Array.isArray(items) ? items : []).map(item => {
    const source = item && typeof item === 'object' ? item : {name:text(item, 'Unknown item')};
    const originalSlot = text(source.slot, source.equipped ? 'Equipped' : 'Carried');
    const isProtectiveGear = /^armor$/i.test(originalSlot) || /^protective gear$/i.test(text(source.equipment_family));
    return {...source, slot:isProtectiveGear ? 'Protective Gear' : originalSlot,
      name:text(source.name, 'Unknown item'), detail:text(source.detail || source.description),
      equipment_family:isProtectiveGear ? 'Protective Gear' : text(source.equipment_family, 'Equipment'),
      quality_level:normalizeQualityLevel(source.quality_level ?? source.qualityLevel)};
  });
}

export function validateEquipment(items) {
  const normalized = normalizeEquipment(items);
  return {valid:normalized.every(item => Number.isInteger(item.quality_level)
      && item.quality_level >= 1 && item.quality_level <= 5
      && ['Equipment','Protective Gear'].includes(item.equipment_family)), value:normalized};
}
