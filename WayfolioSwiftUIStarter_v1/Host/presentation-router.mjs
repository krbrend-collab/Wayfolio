import {PLAY_MODES, normalizeSessionRuntime} from './session-runtime.mjs';

function normalizedAudience(value = {}) {
  const kind = String(value?.kind || 'shared');
  return {
    kind:kind === 'public' ? 'shared' : kind,
    player_id:value?.player_id ? String(value.player_id) : null,
  };
}

/**
 * Central audience-first presentation policy. Campaign state never depends on
 * this decision; changing play mode changes only eligible projection targets.
 */
export function presentationRecipient(runtime, audience, clientMeta = {}) {
  const mode = normalizeSessionRuntime(runtime).play_mode;
  const target = normalizedAudience(audience);
  if (target.kind === 'host') return clientMeta.role === 'dm';
  if (target.kind === 'player') {
    return clientMeta.role === 'wayfolio' && clientMeta.playerID === target.player_id;
  }
  if (target.kind === 'wayfolios') return clientMeta.role === 'wayfolio';
  if (target.kind !== 'shared') return clientMeta.role === 'dm';
  if (clientMeta.role === 'dm') return true;
  if (mode === PLAY_MODES.IPHONE_ONLY) return clientMeta.role === 'wayfolio';
  return clientMeta.role === 'screen';
}

export function publicPresentationRecipient(runtime, clientMeta = {}) {
  return presentationRecipient(runtime, {kind:'shared'}, clientMeta);
}

export function presentationRoute(runtime) {
  const mode = normalizeSessionRuntime(runtime).play_mode;
  return mode === PLAY_MODES.IPHONE_ONLY
    ? {public_display:'wayfolio', personal_display:'wayfolio', shared_ipad:'none'}
    : {public_display:'shared_ipad', personal_display:'wayfolio', shared_ipad:'optional'};
}
