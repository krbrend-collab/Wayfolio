const TUTORIAL_ID = 'renn-intro-tutorial';
const CARE_CENTER_ID = 'location_creature_care_center';
const BRIDGE_ENTITY_IDS = new Set(['bridge-motes', 'crown-hare']);

function uniqueByID(values = []) {
  const result = [];
  const seen = new Set();
  for (const value of values) {
    if (!value?.id || seen.has(value.id)) continue;
    seen.add(value.id);
    result.push(structuredClone(value));
  }
  return result;
}

function uniqueStrings(values = []) {
  return [...new Set(values.filter(value => typeof value === 'string' && value.trim()).map(value => value.trim()))];
}

export function reconcilePartyPresence(worldState, characterLifecycle = {}) {
  const world = structuredClone(worldState);
  world.party = (world.party || []).map(member => {
    const lifecycle = characterLifecycle[member.id];
    if (!lifecycle) return member;
    const publiclyEligible = ['active', 'temporary'].includes(lifecycle.party_membership)
      && lifecycle.reveal_state === 'introduced';
    return {...member, present:publiclyEligible && lifecycle.scene_presence === 'present'};
  });
  return world;
}

export function reconcileJourneyProjection({journeyID, worldState, characterLifecycle, tutorialWorldState}) {
  let world = reconcilePartyPresence(worldState, characterLifecycle);
  const corrections = [];
  if (journeyID !== TUTORIAL_ID || world.location?.id !== CARE_CENTER_ID || !tutorialWorldState) {
    return {worldState:world, corrections};
  }

  const contaminatedEntities = (world.active_entities || []).filter(entity => BRIDGE_ENTITY_IDS.has(entity.id));
  if (contaminatedEntities.length) corrections.push('Removed Hemlock Bridge entities from the Creature Care Center scene.');
  const retainedEntities = (world.active_entities || []).filter(entity => !BRIDGE_ENTITY_IDS.has(entity.id));
  world.active_entities = uniqueByID([...retainedEntities, ...(tutorialWorldState.active_entities || [])]);

  const bridgeClues = new Set([
    'The motes do not merely drift against the wind; they can gather into a coherent luminous trail beneath the bridge rail.',
  ]);
  const retainedClues = (world.known_clues || []).filter(clue => !bridgeClues.has(clue));
  if (retainedClues.length !== (world.known_clues || []).length) corrections.push('Removed a Hemlock Bridge clue from the tutorial projection.');
  world.known_clues = uniqueStrings([...(tutorialWorldState.known_clues || []), ...retainedClues]);

  const bridgePressures = new Set([
    'The motes are gathering around the southern rail.',
    'Tracks end where the blue light begins.',
    'The Crown Hare may reveal or conceal the route beneath the bridge.',
  ]);
  world.open_pressures = uniqueStrings([
    ...(tutorialWorldState.open_pressures || []),
    ...(world.open_pressures || []).filter(pressure => !bridgePressures.has(pressure)),
  ]);

  const templateParty = tutorialWorldState.party || [];
  world.party = uniqueByID([...(world.party || []), ...templateParty]);
  world = reconcilePartyPresence(world, characterLifecycle);
  return {worldState:world, corrections};
}

export function absentCharacterActions(adjudication, worldState, knownCharacters = []) {
  const present = new Set((worldState.party || []).filter(member => member.present).map(member => member.id));
  const presentDialogue = new Set(present);
  for (const entity of worldState.active_entities || []) {
    if (entity.location_id && entity.location_id !== worldState.location?.id) continue;
    if (/npc|person|character|speaker/i.test(String(entity.kind || ''))) presentDialogue.add(entity.id);
  }
  const absent = knownCharacters.filter(character => !present.has(character.id));
  const prose = String(adjudication?.public_narration || '');
  const actionWords = '(?:says|asks|answers|replies|calls|shouts|whispers|speaks|nods|gestures|walks|runs|steps|looks|watches|helps|moves|reaches|takes|gives|follows|waits)';
  const violations = [];
  for (const line of adjudication?.companion_lines || []) {
    if (!presentDialogue.has(line.speaker_id)) violations.push(`Absent character ${line.speaker_id} was given dialogue.`);
  }
  for (const character of absent) {
    const names = [...new Set([character.name, character.name.split(/\s+/)[0]].filter(Boolean))];
    const actsInScene = names.some(name => {
      const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      return new RegExp(`\\b${escaped}\\b\\s+${actionWords}\\b`, 'iu').test(prose);
    });
    if (actsInScene) {
      violations.push(`Absent character ${character.id} was narrated as acting.`);
    }
  }
  return violations;
}
