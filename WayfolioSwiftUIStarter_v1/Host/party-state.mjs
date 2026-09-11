const states = Object.freeze({
  recruitment:new Set(['not_applicable', 'not_recruited', 'opportunity', 'accepted', 'conditional', 'declined']),
  membership:new Set(['inactive', 'temporary', 'active']),
  reveal:new Set(['hidden', 'pending_introduction', 'introduced']),
  playability:new Set(['npc_controlled', 'provisional_import', 'available_to_play']),
  presence:new Set(['absent', 'present']),
});

function clean(value, allowed, fallback) {
  return allowed.has(value) ? value : fallback;
}

export function defaultCharacterLifecycle(character) {
  const isRenn = character?.id === 'renn';
  const isYugen = character?.id === 'yugen';
  const isHinosuke = character?.id === 'hinosuke';
  const isEstablishedCompanion = ['soren', 'lupin'].includes(character?.id);
  const isPendingPlayerParty = isYugen || isHinosuke;
  return {
    character_id:character?.id,
    character_name:character?.name,
    recruitment_state:isRenn ? 'not_applicable' : isEstablishedCompanion || isPendingPlayerParty ? 'accepted' : 'not_recruited',
    party_membership:isRenn || isEstablishedCompanion || isPendingPlayerParty ? 'active' : 'inactive',
    reveal_state:isRenn || isEstablishedCompanion ? 'introduced' : isPendingPlayerParty ? 'pending_introduction' : 'hidden',
    playability:isRenn || isYugen ? 'available_to_play' : isEstablishedCompanion || isHinosuke ? 'npc_controlled' : 'provisional_import',
    player_assignment:{status:'unassigned', player_id:null},
    wayfolio_binding:{status:'unbound', device_id:null},
    scene_presence:isRenn || isEstablishedCompanion ? 'present' : 'absent',
    updated_at:null,
  };
}

export function normalizeCharacterLifecycle(saved = {}, characters = new Map()) {
  const result = {};
  for (const character of characters.values()) {
    const fallback = defaultCharacterLifecycle(character);
    const value = saved?.[character.id] || {};
    result[character.id] = {
      character_id:character.id,
      character_name:character.name,
      recruitment_state:clean(value.recruitment_state, states.recruitment, fallback.recruitment_state),
      party_membership:clean(value.party_membership, states.membership, fallback.party_membership),
      reveal_state:clean(value.reveal_state, states.reveal, fallback.reveal_state),
      playability:clean(value.playability, states.playability, fallback.playability),
      player_assignment:{
        status:value.player_assignment?.status === 'assigned' ? 'assigned' : 'unassigned',
        player_id:value.player_assignment?.status === 'assigned' ? value.player_assignment.player_id || null : null,
      },
      wayfolio_binding:{
        status:value.wayfolio_binding?.status === 'bound' ? 'bound' : 'unbound',
        device_id:value.wayfolio_binding?.status === 'bound' ? value.wayfolio_binding.device_id || null : null,
      },
      scene_presence:clean(value.scene_presence, states.presence, fallback.scene_presence),
      updated_at:value.updated_at || null,
    };
  }
  return result;
}

export function isPublicPartyEligible(lifecycle) {
  return Boolean(lifecycle)
    && ['active', 'temporary'].includes(lifecycle.party_membership)
    && lifecycle.reveal_state === 'introduced';
}

export function isWayfolioSelectable(lifecycle) {
  return Boolean(lifecycle)
    && lifecycle.playability === 'available_to_play';
}

export function introducePartyMember(lifecycle, now = new Date().toISOString()) {
  if (!lifecycle || !['active', 'temporary'].includes(lifecycle.party_membership)) {
    throw new Error('Only a character who has joined the party can be introduced.');
  }
  if (lifecycle.reveal_state !== 'pending_introduction') {
    throw new Error(lifecycle.reveal_state === 'introduced'
      ? 'That party member has already been introduced.'
      : 'That character is not waiting for an in-story introduction.');
  }
  return {...lifecycle, reveal_state:'introduced', updated_at:now};
}

export function bindWayfolio(lifecycle, {playerID = null, deviceID = null} = {}, now = new Date().toISOString()) {
  if (!isWayfolioSelectable(lifecycle)) throw new Error('That character is not currently available to play.');
  return {...lifecycle,
    player_assignment:{status:'assigned', player_id:playerID},
    wayfolio_binding:{status:'bound', device_id:deviceID}, updated_at:now};
}

export function releaseWayfolio(lifecycle, now = new Date().toISOString()) {
  if (!lifecycle) return lifecycle;
  return {...lifecycle, player_assignment:{status:'unassigned', player_id:null},
    wayfolio_binding:{status:'unbound', device_id:null}, updated_at:now};
}

export function spriteDiagnostic(character) {
  const identity = character?.visual_identity || {};
  const approvedReferences = (identity.references || []).filter(reference => reference.approved);
  const approvedVersion = Number(identity.approved_version || identity.version || 0) || null;
  const localVersion = approvedReferences.length ? approvedVersion : null;
  return {
    character_id:character?.id,
    name:character?.name,
    approved_version:approvedVersion,
    local_version:localVersion,
    update_state:approvedReferences.length ? 'current' : 'approved_assets_missing_locally',
    approved_reference_count:approvedReferences.length,
    login_metadata_valid:Boolean(approvedReferences.length && approvedVersion),
    private_note:approvedReferences.length
      ? 'Approved identity reference is available to the host.'
      : 'No approved local sprite/reference is available. Do not substitute or expose unrevealed art.',
  };
}
