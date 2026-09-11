const REACTION_MODES = new Set(['ASK', 'AUTOMATIC', 'OFF']);
const KNOWLEDGE_SCOPES = new Set(['PARTY', 'CHARACTER', 'PRIVATE', 'PUBLIC_WORLD']);
const NAVIGATION_STATES = new Set(['DISCOVERED', 'RELEVANT', 'DESTINATION']);

function text(value) { return String(value || '').trim(); }
function list(value) { return Array.isArray(value) ? value : []; }

export function normalizeReactionMode(value) {
  const mode = text(value).toUpperCase();
  return REACTION_MODES.has(mode) ? mode : 'ASK';
}

export function reactionPolicyFor(state = {}, behaviorClass = 'general') {
  return normalizeReactionMode(state?.reaction_policies?.[text(behaviorClass) || 'general']);
}

export function updateReactionPolicy(state, input = {}) {
  const behaviorClass = text(input.behavior_class) || 'general';
  const mode = normalizeReactionMode(input.mode);
  if (mode === 'AUTOMATIC' && input.explicit_authorization !== true) {
    throw new Error('Automatic handling requires explicit authorization from the owning player.');
  }
  state.reaction_policies ||= {};
  state.reaction_policies[behaviorClass] = mode;
  return {behavior_class:behaviorClass, mode};
}

export function reactionDisposition(state, behaviorClass) {
  const mode = reactionPolicyFor(state, behaviorClass);
  if (mode === 'OFF') return {mode, outcome:'DISABLED'};
  if (mode === 'AUTOMATIC') return {mode, outcome:'AUTHORITATIVE_RESOLUTION_ALLOWED'};
  return {mode:'ASK', outcome:'PLAYER_DECISION_REQUIRED'};
}

export function normalizeKnowledgeScope(value) {
  const normalized = text(value).toUpperCase().replace(/[ -]+/g, '_');
  if (normalized === 'PUBLIC' || normalized === 'WORLD') return 'PUBLIC_WORLD';
  return KNOWLEDGE_SCOPES.has(normalized) ? normalized : 'CHARACTER';
}

export function canReceiveKnowledge(record = {}, viewer = {}) {
  if (viewer.role === 'dm' || viewer.role === 'host') return true;
  const scope = normalizeKnowledgeScope(record.knowledge_scope);
  if (scope === 'PUBLIC_WORLD') return true;
  if (scope === 'PARTY') return viewer.role === 'wayfolio' || viewer.role === 'screen';
  const owner = text(record.owner_character_id || record.character_id);
  if (scope === 'CHARACTER') return viewer.role === 'wayfolio' && owner === text(viewer.character_id);
  if (scope === 'PRIVATE') return viewer.role === 'wayfolio' && owner === text(viewer.character_id);
  return false;
}

export function normalizeNavigationState(value) {
  const state = text(value).toUpperCase();
  return NAVIGATION_STATES.has(state) ? state : 'DISCOVERED';
}

export function eligibleAffordances(affordances, viewer = {}) {
  return list(affordances).filter(value => value && value.perceived !== false && canReceiveKnowledge({
    knowledge_scope:value.knowledge_scope || 'PARTY', owner_character_id:value.owner_character_id,
  }, viewer)).map(value => ({
    id:text(value.id), kind:text(value.kind), label:text(value.label),
    relevance:Number(value.relevance || 0), knowledge_scope:normalizeKnowledgeScope(value.knowledge_scope || 'PARTY'),
  })).filter(value => value.id && value.kind).sort((a, b) => b.relevance - a.relevance).slice(0, 4);
}

export function normalizeNarrativeMoment(value = {}) {
  return {
    id:text(value.id), requirements:list(value.requirements).map(String), priority:Number(value.priority || 0),
    expires_at:value.expires_at || null, invalidated:value.invalidated === true,
    participant_ids:list(value.participant_ids).map(String), location_id:text(value.location_id) || null,
    scene_id:text(value.scene_id) || null, knowledge_scope:normalizeKnowledgeScope(value.knowledge_scope || 'PARTY'),
    owner_character_id:text(value.owner_character_id) || null, tone:text(value.tone) || null,
    presentation:text(value.presentation) || null,
  };
}

export function eligibleNarrativeMoments(queue, context = {}, viewer = {}, now = new Date()) {
  const satisfied = new Set(list(context.satisfied_requirements).map(String));
  return list(queue).map(normalizeNarrativeMoment).filter(moment => {
    if (!moment.id || moment.invalidated) return false;
    if (moment.expires_at && Date.parse(moment.expires_at) <= now.getTime()) return false;
    if (moment.location_id && moment.location_id !== text(context.location_id)) return false;
    if (moment.scene_id && moment.scene_id !== text(context.scene_id)) return false;
    if (moment.participant_ids.length && !moment.participant_ids.every(id => list(context.participant_ids).map(String).includes(id))) return false;
    if (!moment.requirements.every(value => satisfied.has(value))) return false;
    return canReceiveKnowledge(moment, viewer);
  }).sort((a, b) => b.priority - a.priority);
}
