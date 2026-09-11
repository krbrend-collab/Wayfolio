function normalizedID(value) {
  return String(value || '').trim().toLowerCase().replace(/\s+/g, '_');
}

function registryProfileID(registry, value) {
  const requested = normalizedID(value);
  if (registry?.profiles?.[requested]) return requested;
  const match = Object.entries(registry?.profiles || {}).find(([, profile]) =>
    (profile.aliases || []).some(alias => normalizedID(alias) === requested));
  return match?.[0] || null;
}

export function normalizeVoiceAssignmentState(value = {}, registry = {}, now = new Date().toISOString()) {
  const assignments = {};
  for (const [key, record] of Object.entries(value?.assignments || {})) {
    const speakerID = normalizedID(record?.speaker_id || key);
    const profileID = registryProfileID(registry, record?.voice_profile_id);
    if (!speakerID || !profileID) continue;
    assignments[speakerID] = {
      speaker_id:speakerID,
      voice_profile_id:profileID,
      source:record?.source || 'restored',
      assigned_at:record?.assigned_at || now,
      updated_at:record?.updated_at || record?.assigned_at || now,
    };
  }
  return {
    schema_version:1,
    revision:Math.max(0, Number(value?.revision || 0)),
    assignments,
  };
}

export function resolveVoiceAssignment(state, {
  speakerID,
  requestedProfileID = null,
  registry = {},
  allowReassignment = false,
  now = new Date().toISOString(),
} = {}) {
  const normalized = normalizeVoiceAssignmentState(state, registry, now);
  const speaker = normalizedID(speakerID) || normalizedID(registry.default_profile) || 'narrator';
  const existing = normalized.assignments[speaker];
  const requested = registryProfileID(registry, requestedProfileID);
  if (existing && (!allowReassignment || !requested || requested === existing.voice_profile_id)) {
    return {state:normalized, assignment:existing, changed:false};
  }

  const profileID = requested
    || registryProfileID(registry, speaker)
    || registryProfileID(registry, registry.default_profile)
    || Object.keys(registry.profiles || {})[0]
    || 'narrator';
  const assignment = {
    speaker_id:speaker,
    voice_profile_id:profileID,
    source:existing ? 'explicit_reassignment' : requested ? 'requested_profile' : registryProfileID(registry, speaker) ? 'speaker_profile' : 'campaign_fallback',
    assigned_at:existing?.assigned_at || now,
    updated_at:now,
  };
  normalized.assignments[speaker] = assignment;
  normalized.revision += 1;
  return {state:normalized, assignment, changed:true};
}

export function voiceAssignmentProjection(state = {}) {
  return {
    schema_version:1,
    revision:Math.max(0, Number(state?.revision || 0)),
    assignments:Object.values(state?.assignments || {}).map(record => ({
      speaker_id:record.speaker_id,
      voice_profile_id:record.voice_profile_id,
      source:record.source,
    })).sort((a, b) => a.speaker_id.localeCompare(b.speaker_id)),
  };
}
