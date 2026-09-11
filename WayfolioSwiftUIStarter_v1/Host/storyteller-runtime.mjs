import {createHash, randomUUID} from 'node:crypto';

export const STORYTELLER_PROTOCOL_VERSION = 'wayfolio.storyteller.v1';
export const VISIBILITY_SCOPES = new Set(['GM_ONLY', 'PARTY', 'PLAYER_IDS', 'CHARACTER_IDS', 'PUBLIC_SESSION']);
export const RESPONSE_MODES = new Set(['FINAL', 'NEEDS_RESOLUTION', 'REPAIR']);

const RESOLUTION_TYPES = new Set([
  'ability_check', 'saving_throw', 'attack', 'damage', 'contested_check', 'initiative',
  'resource_spend', 'item_use', 'movement', 'condition', 'crafting', 'payment',
]);

function text(value, fallback = '') { return typeof value === 'string' ? value : fallback; }
function list(value) { return Array.isArray(value) ? value : []; }
function object(value) { return value && typeof value === 'object' && !Array.isArray(value) ? value : {}; }
function hash(value) { return createHash('sha256').update(JSON.stringify(value)).digest('hex'); }
function bounded(value, maximum = 200) { return list(value).slice(0, maximum); }

export function createStorytellerState(value = {}) {
  return {
    protocolVersion:STORYTELLER_PROTOCOL_VERSION,
    stateVersion:Number.isInteger(value.stateVersion) && value.stateVersion >= 0 ? value.stateVersion : 0,
    pendingTurns:object(value.pendingTurns),
    processedTurns:object(value.processedTurns),
    stableIdMappings:object(value.stableIdMappings),
    continuity:bounded(value.continuity, 200),
    threadLifecycles:object(value.threadLifecycles),
    generationLeases:object(value.generationLeases),
  };
}

function timestamp(value = Date.now()) {
  const result = typeof value === 'string' ? Date.parse(value) : Number(value);
  return Number.isFinite(result) ? result : Date.now();
}

function iso(value = Date.now()) { return new Date(timestamp(value)).toISOString(); }

// A lease is persisted before provider work begins. The process owner makes a
// crashed host distinguishable from a duplicate request still running in the
// same process, while the idempotency key keeps the canonical turn singular.
export function acquireStorytellerGenerationLease(stateInput, input = {}) {
  const state = createStorytellerState(stateInput);
  const actorId = text(input.actorId); const turnId = text(input.turnId);
  const idempotencyKey = text(input.idempotencyKey); const ownerId = text(input.ownerId);
  if (!actorId || !turnId || !idempotencyKey || !ownerId) throw new Error('A storyteller lease requires actorId, turnId, idempotencyKey, and ownerId.');
  const now = timestamp(input.now); const duration = Math.max(1_000, Number(input.leaseDurationMs) || 90_000);
  const fingerprint = hash({actorId, turnId, payload:object(input.pendingInteraction), visibility:normalizeVisibility(input.visibility)});
  const existing = state.generationLeases[idempotencyKey];
  if (existing) {
    if (existing.fingerprint !== fingerprint) throw new Error('A storyteller lease idempotency key was reused with different content.');
    if (existing.status === 'COMPLETED') return {status:'REPLAY', replayed:true, state, lease:existing, result:existing.result || null};
    if (existing.status === 'ACTIVE' && existing.ownerId === ownerId && timestamp(existing.expiresAt) > now) {
      return {status:'HELD', replayed:true, state, lease:existing};
    }
  }
  const lifecycle = object(state.threadLifecycles[actorId]);
  const threadId = text(input.threadId) || text(existing?.threadId) || text(lifecycle.threadId)
    || `storyteller:${actorId}:${randomUUID()}`;
  state.threadLifecycles[actorId] = {...lifecycle, actorId, threadId, status:'ACTIVE',
    generation:Math.max(1, Number(lifecycle.generation) || 1), createdAt:lifecycle.createdAt || iso(now),
    lastHealthyAt:iso(now), replacedBy:null};
  const lease = {idempotencyKey, fingerprint, actorId, turnId, threadId, ownerId, status:'ACTIVE',
    attempt:Math.max(0, Number(existing?.attempt) || 0) + 1, acquiredAt:iso(now), expiresAt:iso(now + duration),
    visibility:normalizeVisibility(input.visibility), pendingInteraction:object(input.pendingInteraction), result:null,
    lastError:existing?.lastError || null};
  state.generationLeases[idempotencyKey] = lease;
  return {status:'ACQUIRED', replayed:false, recovered:Boolean(existing), state, lease};
}

export function completeStorytellerGenerationLease(stateInput, input = {}) {
  const state = createStorytellerState(stateInput); const key = text(input.idempotencyKey);
  const lease = state.generationLeases[key];
  if (!lease) throw new Error('No storyteller generation lease matches this completion.');
  if (input.ownerId && lease.ownerId !== input.ownerId) throw new Error('Only the current storyteller lease owner may complete it.');
  if (lease.status === 'COMPLETED') return {status:'REPLAY', replayed:true, state, lease, result:lease.result || null};
  const completedAt = iso(input.now);
  const completed = {...lease, status:'COMPLETED', completedAt, expiresAt:completedAt,
    result:input.result === undefined ? null : input.result, lastError:null};
  state.generationLeases[key] = completed;
  const lifecycle = object(state.threadLifecycles[lease.actorId]);
  state.threadLifecycles[lease.actorId] = {...lifecycle, status:'ACTIVE', lastHealthyAt:completedAt};
  return {status:'COMPLETED', replayed:false, state, lease:completed, result:completed.result};
}

export function failStorytellerGenerationLease(stateInput, input = {}) {
  const state = createStorytellerState(stateInput); const key = text(input.idempotencyKey);
  const lease = state.generationLeases[key];
  if (!lease) return {status:'MISSING', state};
  if (input.ownerId && lease.ownerId !== input.ownerId) return {status:'STALE_OWNER', state, lease};
  const failedAt = iso(input.now);
  state.generationLeases[key] = {...lease, status:'RECOVERABLE', failedAt, expiresAt:failedAt,
    lastError:text(input.error, 'Storyteller generation was interrupted.')};
  const lifecycle = object(state.threadLifecycles[lease.actorId]);
  state.threadLifecycles[lease.actorId] = {...lifecycle, status:'DEGRADED', lastError:state.generationLeases[key].lastError};
  return {status:'RECOVERABLE', state, lease:state.generationLeases[key]};
}

export function rolloverStorytellerThread(stateInput, input = {}) {
  const state = createStorytellerState(stateInput); const actorId = text(input.actorId);
  if (!actorId) throw new Error('A storyteller thread rollover requires actorId.');
  const now = iso(input.now); const prior = object(state.threadLifecycles[actorId]);
  const fromThreadId = text(input.fromThreadId) || text(prior.threadId) || null;
  const toThreadId = text(input.toThreadId) || `storyteller:${actorId}:${randomUUID()}`;
  state.threadLifecycles[actorId] = {actorId, threadId:toThreadId, status:'ACTIVE',
    generation:Math.max(0, Number(prior.generation) || 0) + 1, createdAt:now, lastHealthyAt:now,
    replaces:fromThreadId, replacedBy:null, reason:text(input.reason, 'safe rollover')};
  for (const [key, lease] of Object.entries(state.generationLeases)) {
    if (lease.actorId !== actorId || lease.status === 'COMPLETED') continue;
    state.generationLeases[key] = {...lease, threadId:toThreadId, status:'RECOVERABLE', ownerId:'',
      expiresAt:now, rolloverAt:now};
  }
  return {status:'ROLLED_OVER', state, fromThreadId, toThreadId};
}

// Deliberately contains only bounded canonical state and the unresolved input;
// a replacement thread never depends on access to a provider transcript.
export function buildStorytellerResumeContext(stateInput, input = {}) {
  const state = createStorytellerState(stateInput); const actorId = text(input.actorId);
  const pending = Object.values(state.generationLeases).filter(lease => lease.actorId === actorId && lease.status !== 'COMPLETED')
    .sort((a, b) => timestamp(b.acquiredAt) - timestamp(a.acquiredAt))[0] || null;
  return {protocolVersion:STORYTELLER_PROTOCOL_VERSION, sessionId:text(input.sessionId), actorId,
    stateVersion:state.stateVersion, threadLifecycle:object(state.threadLifecycles[actorId]),
    continuity:state.continuity.slice(-50), campaignSnapshot:object(input.campaignSnapshot),
    pendingInteraction:pending ? {turnId:pending.turnId, idempotencyKey:pending.idempotencyKey,
      visibility:pending.visibility, input:pending.pendingInteraction} : null};
}

export function normalizeVisibility(value, fallback = {scope:'PARTY'}) {
  const source = object(value);
  const scope = VISIBILITY_SCOPES.has(source.scope) ? source.scope : fallback.scope;
  return {
    scope,
    playerIds:scope === 'PLAYER_IDS' ? bounded(source.playerIds, 50).map(String) : [],
    characterIds:scope === 'CHARACTER_IDS' ? bounded(source.characterIds, 50).map(String) : [],
  };
}

export function canViewVisibility(visibility, viewer = {}) {
  const value = normalizeVisibility(visibility);
  if (viewer.role === 'dm' || viewer.role === 'host') return true;
  if (value.scope === 'GM_ONLY') return false;
  if (value.scope === 'PARTY' || value.scope === 'PUBLIC_SESSION') return true;
  if (value.scope === 'PLAYER_IDS') return value.playerIds.includes(String(viewer.playerId || ''));
  if (value.scope === 'CHARACTER_IDS') return value.characterIds.includes(String(viewer.characterId || viewer.playerId || ''));
  return false;
}

export function buildStorytellerContext(input) {
  const declaration = text(input.playerInput?.rawIntent);
  const context = {
    protocolVersion:STORYTELLER_PROTOCOL_VERSION,
    sessionId:text(input.sessionId), turnId:text(input.turnId), stateVersion:Number(input.stateVersion),
    sceneId:text(input.sceneId), trigger:text(input.trigger), causationId:text(input.causationId),
    playerInput:{...object(input.playerInput), rawIntent:declaration},
    canon:{locked:bounded(input.canon?.locked), established:bounded(input.canon?.established),
      gmOnly:bounded(input.canon?.gmOnly), unresolvedThreads:bounded(input.canon?.unresolvedThreads),
      continuitySummary:bounded(input.canon?.continuitySummary), constraints:bounded(input.canon?.constraints)},
    scene:object(input.scene), mechanics:object(input.mechanics), knowledge:object(input.knowledge),
    capabilities:object(input.capabilities),
  };
  const result = validateStorytellerContext(context);
  if (!result.valid) throw new Error(`Invalid StorytellerContext: ${result.errors.join(', ')}`);
  return context;
}

export function validateStorytellerContext(value) {
  const errors = [];
  if (value?.protocolVersion !== STORYTELLER_PROTOCOL_VERSION) errors.push('protocolVersion');
  for (const key of ['sessionId','turnId','sceneId','trigger','causationId']) if (!text(value?.[key])) errors.push(key);
  if (!Number.isInteger(value?.stateVersion) || value.stateVersion < 0) errors.push('stateVersion');
  if (!text(value?.playerInput?.rawIntent) && value?.trigger === 'player_action') errors.push('playerInput.rawIntent');
  return {valid:errors.length === 0, errors};
}

function normalizeNarrativeSegment(value, turnId, index) {
  const segment = object(value);
  return {
    segmentId:text(segment.segmentId, `${turnId}:segment:${index + 1}`),
    visibility:normalizeVisibility(segment.visibility), speakerId:text(segment.speakerId) || null,
    speakerName:text(segment.speakerName) || null, text:text(segment.text).trim(),
    delivery:text(segment.delivery) || null, modality:text(segment.modality, 'narrator'),
    voiceProfileId:text(segment.voiceProfileId) || null,
    dependsOnResolutionIds:bounded(segment.dependsOnResolutionIds, 20).map(String),
  };
}

function normalizeResolution(value, turnId, index) {
  const resolution = object(value);
  return {
    resolutionId:text(resolution.resolutionId, `${turnId}:resolution:${index + 1}`),
    type:text(resolution.type), actorId:text(resolution.actorId), targetIds:bounded(resolution.targetIds, 20).map(String),
    mechanic:object(resolution.mechanic), challenge:object(resolution.challenge),
    advantageState:['advantage','disadvantage','normal'].includes(resolution.advantageState) ? resolution.advantageState : 'normal',
    visibility:normalizeVisibility(resolution.visibility), reason:text(resolution.reason).slice(0, 1000),
  };
}

function normalizeProposal(value, turnId, index) {
  const proposal = object(value);
  return {
    proposalId:text(proposal.proposalId, `${turnId}:proposal:${index + 1}`), eventType:text(proposal.eventType),
    entityRefs:bounded(proposal.entityRefs, 50).map(String), payload:object(proposal.payload),
    persistence:['persistent','session','ephemeral'].includes(proposal.persistence) ? proposal.persistence : 'session',
    visibility:normalizeVisibility(proposal.visibility), cause:text(proposal.cause, turnId),
    dependsOnResolutionIds:bounded(proposal.dependsOnResolutionIds, 20).map(String),
  };
}

function normalizeKnowledgeGrant(value, turnId, index) {
  const grant = object(value);
  return {
    knowledgeGrantId:text(grant.knowledgeGrantId, `${turnId}:knowledge:${index + 1}`),
    recipientCharacterIds:bounded(grant.recipientCharacterIds, 50).map(String), party:Boolean(grant.party),
    entityRef:text(grant.entityRef), operation:text(grant.operation), content:object(grant.content),
    knowledgeLevel:text(grant.knowledgeLevel) || null, source:text(grant.source),
    manifestation:Boolean(grant.manifestation), announcementText:text(grant.announcementText) || null,
  };
}

function normalizeCanonProposal(value, turnId, index) {
  const proposal = object(value);
  return {
    temporaryId:text(proposal.temporaryId, `temp:entity:${index + 1}`), entityType:text(proposal.entityType),
    publicFacts:object(proposal.publicFacts), gmOnlyFacts:object(proposal.gmOnlyFacts),
    relationships:bounded(proposal.relationships, 50),
    persistenceRecommendation:['persistent','session','ephemeral'].includes(proposal.persistenceRecommendation)
      ? proposal.persistenceRecommendation : 'session', rationale:text(proposal.rationale), originatingTurnId:turnId,
  };
}

export function normalizeStorytellerTurn(value) {
  const source = object(value); const turnId = text(source.turnId);
  const result = {
    protocolVersion:text(source.protocolVersion), sessionId:text(source.sessionId), turnId,
    basedOnStateVersion:Number(source.basedOnStateVersion), responseMode:text(source.responseMode),
    narrativeSegments:list(source.narrativeSegments).map((item, index) => normalizeNarrativeSegment(item, turnId, index)),
    resolutionRequests:list(source.resolutionRequests).map((item, index) => normalizeResolution(item, turnId, index)),
    proposedGameEvents:list(source.proposedGameEvents).map((item, index) => normalizeProposal(item, turnId, index)),
    knowledgeGrants:list(source.knowledgeGrants).map((item, index) => normalizeKnowledgeGrant(item, turnId, index)),
    canonProposals:list(source.canonProposals).map((item, index) => normalizeCanonProposal(item, turnId, index)),
    presentationContext:source.presentationContext ? object(source.presentationContext) : null,
    continuityUpdates:bounded(source.continuityUpdates, 50),
    nextInput:{awaitingInput:Boolean(source.nextInput?.awaitingInput),
      expectedActorIds:bounded(source.nextInput?.expectedActorIds, 20).map(String),
      inputType:text(source.nextInput?.inputType, 'free-action'), promptText:text(source.nextInput?.promptText) || null},
  };
  return result;
}

export function validateStorytellerTurn(value) {
  const turn = normalizeStorytellerTurn(value); const errors = [];
  if (turn.protocolVersion !== STORYTELLER_PROTOCOL_VERSION) errors.push('protocolVersion');
  for (const key of ['sessionId','turnId']) if (!text(turn[key])) errors.push(key);
  if (!Number.isInteger(turn.basedOnStateVersion) || turn.basedOnStateVersion < 0) errors.push('basedOnStateVersion');
  if (!RESPONSE_MODES.has(turn.responseMode)) errors.push('responseMode');
  if (turn.narrativeSegments.some(segment => !segment.text)) errors.push('narrativeSegments.text');
  if (turn.resolutionRequests.some(item => !item.resolutionId || !RESOLUTION_TYPES.has(item.type) || !item.actorId)) errors.push('resolutionRequests');
  if (turn.responseMode === 'NEEDS_RESOLUTION' && !turn.resolutionRequests.length) errors.push('resolutionRequests.required');
  if (turn.responseMode === 'FINAL' && turn.resolutionRequests.length) errors.push('resolutionRequests.final');
  if (turn.proposedGameEvents.some(item => !item.proposalId || !item.eventType)) errors.push('proposedGameEvents');
  if (turn.knowledgeGrants.some(item => !item.entityRef || !item.operation || (!item.party && !item.recipientCharacterIds.length))) errors.push('knowledgeGrants');
  if (turn.canonProposals.some(item => !item.temporaryId.startsWith('temp:') || !item.entityType)) errors.push('canonProposals');
  return {valid:errors.length === 0, errors, value:turn};
}

export function prepareStorytellerTurn(stateInput, context, turnInput) {
  const state = createStorytellerState(stateInput);
  const contextValidation = validateStorytellerContext(context);
  if (!contextValidation.valid) throw new Error(`Invalid StorytellerContext: ${contextValidation.errors.join(', ')}`);
  const validation = validateStorytellerTurn(turnInput);
  if (!validation.valid) throw new Error(`Invalid StorytellerTurn: ${validation.errors.join(', ')}`);
  const turn = validation.value;
  if (turn.sessionId !== context.sessionId || turn.turnId !== context.turnId) throw new Error('StorytellerTurn does not match its context.');
  const fingerprint = hash({context, turn}); const prior = state.processedTurns[turn.turnId];
  if (prior) {
    if (prior.fingerprint !== fingerprint) throw new Error('A processed turnId was reused with different content.');
    return {state, ...prior.result, status:'REPLAY', replayed:true};
  }
  if (turn.basedOnStateVersion !== state.stateVersion || context.stateVersion !== state.stateVersion) {
    return {status:'STALE_STATE', repairRequired:true, state, expectedStateVersion:state.stateVersion};
  }
  if (turn.responseMode === 'NEEDS_RESOLUTION') {
    state.pendingTurns[turn.turnId] = {fingerprint, contextHash:hash(context), turn};
    return {status:'NEEDS_RESOLUTION', state, turn};
  }
  return {status:turn.responseMode, state, turn};
}

export function buildResolutionPacket(stateInput, input) {
  const state = createStorytellerState(stateInput); const pending = state.pendingTurns[text(input.turnId)];
  if (!pending) throw new Error('No pending storyteller turn matches this resolution.');
  if (Number(input.stateVersion) !== state.stateVersion) return {status:'STALE_STATE', repairRequired:true, state};
  const requested = new Map(pending.turn.resolutionRequests.map(item => [item.resolutionId, item]));
  const results = list(input.results).map(item => ({...object(item), resolutionId:text(item.resolutionId)}));
  if (results.length !== requested.size || results.some(item => !requested.has(item.resolutionId))) {
    throw new Error('ResolutionPacket must answer every requested resolution exactly once.');
  }
  return {protocolVersion:STORYTELLER_PROTOCOL_VERSION, sessionId:pending.turn.sessionId,
    turnId:pending.turn.turnId, stateVersion:state.stateVersion, results,
    visibility:results.map(item => ({resolutionId:item.resolutionId, visibility:requested.get(item.resolutionId).visibility}))};
}

export function commitStorytellerTurn(stateInput, context, turnInput, commit = {}) {
  const prepared = prepareStorytellerTurn(stateInput, context, turnInput);
  if (!['FINAL','REPAIR'].includes(prepared.status)) return prepared;
  const state = prepared.state; const turn = prepared.turn; const stableIdMappings = {};
  for (const proposal of turn.canonProposals) {
    const stableId = text(commit.stableIdMappings?.[proposal.temporaryId], `runtime:${proposal.entityType}:${randomUUID()}`);
    stableIdMappings[proposal.temporaryId] = stableId; state.stableIdMappings[proposal.temporaryId] = stableId;
  }
  state.stateVersion += 1;
  state.continuity.push(...turn.continuityUpdates.map(item => ({turnId:turn.turnId, ...object(item)})));
  state.continuity = state.continuity.slice(-200);
  delete state.pendingTurns[turn.turnId];
  const receipt = {protocolVersion:STORYTELLER_PROTOCOL_VERSION, sessionId:turn.sessionId, turnId:turn.turnId,
    newStateVersion:state.stateVersion, acceptedProposalIds:turn.proposedGameEvents.map(item => item.proposalId),
    normalizedProposals:bounded(commit.normalizedProposals), rejectedProposals:bounded(commit.rejectedProposals),
    stableIdMappings, canonicalEventIds:bounded(commit.canonicalEventIds).map(String), repairRequired:false};
  const result = {status:'COMMITTED', receipt, turn};
  state.processedTurns[turn.turnId] = {fingerprint:hash({context, turn}), result};
  return {state, ...result};
}

export function filterStorytellerTurnForViewer(turnInput, viewer) {
  const turn = normalizeStorytellerTurn(turnInput);
  return {
    ...turn,
    narrativeSegments:turn.narrativeSegments.filter(item => canViewVisibility(item.visibility, viewer)),
    resolutionRequests:turn.resolutionRequests.filter(item => canViewVisibility(item.visibility, viewer)),
    proposedGameEvents:turn.proposedGameEvents.filter(item => canViewVisibility(item.visibility, viewer)),
    canonProposals:viewer.role === 'dm' || viewer.role === 'host'
      ? turn.canonProposals : turn.canonProposals.map(item => ({...item, gmOnlyFacts:{}})),
  };
}

export function legacyAdjudicationToStorytellerTurn({context, adjudication}) {
  const segments = [{segmentId:`${context.turnId}:narrator`, visibility:{scope:'PARTY'}, speakerId:'narrator',
    text:text(adjudication.public_narration), delivery:'responsive, grounded open-play narration', modality:'narrator'}];
  if (text(adjudication.private_information)) segments.push({segmentId:`${context.turnId}:private`,
    visibility:{scope:'CHARACTER_IDS', characterIds:[context.playerInput.actorCharacterId]}, speakerId:'narrator',
    text:adjudication.private_information, modality:'private'});
  for (const [index, line] of list(adjudication.companion_lines).entries()) segments.push({
    segmentId:`${context.turnId}:companion:${index + 1}`, visibility:{scope:'PARTY'}, speakerId:line.speaker_id,
    speakerName:line.speaker_name, voiceProfileId:line.voice_profile_id,
    text:line.text, delivery:line.performance, modality:'dialogue'});
  return normalizeStorytellerTurn({protocolVersion:STORYTELLER_PROTOCOL_VERSION, sessionId:context.sessionId,
    turnId:context.turnId, basedOnStateVersion:context.stateVersion, responseMode:'FINAL', narrativeSegments:segments,
    proposedGameEvents:[], knowledgeGrants:[], canonProposals:[], continuityUpdates:[],
    presentationContext:{locationId:context.scene.locationId, timeOfDay:context.scene.timeOfDay},
    nextInput:{awaitingInput:true, expectedActorIds:[context.playerInput.actorCharacterId], inputType:'free-action'}});
}
