export const PLAY_MODES = Object.freeze({
  IPHONE_ONLY:'iphone_only',
  IPHONE_SHARED_IPAD:'iphone_shared_ipad',
});

export function isPlayMode(value) {
  return Object.values(PLAY_MODES).includes(value);
}

export function normalizeSessionRuntime(value = {}, now = new Date().toISOString()) {
  const playMode = isPlayMode(value?.play_mode) ? value.play_mode : PLAY_MODES.IPHONE_SHARED_IPAD;
  return {
    schema_version:1,
    play_mode:playMode,
    revision:Math.max(0, Number(value?.revision || 0)),
    updated_at:value?.updated_at || now,
    updated_by:value?.updated_by || 'host_restore',
    shared_ipad:{
      last_device_id:value?.shared_ipad?.last_device_id || null,
      last_seen:value?.shared_ipad?.last_seen || null,
    },
  };
}

export function updatePlayMode(runtime, playMode, updatedBy = 'wayfolio', now = new Date().toISOString()) {
  if (!isPlayMode(playMode)) throw new Error('Choose iPhone Only or iPhone + Shared iPad.');
  const current = normalizeSessionRuntime(runtime, now);
  if (current.play_mode === playMode) return current;
  return {...current, play_mode:playMode, revision:current.revision + 1, updated_at:now, updated_by:updatedBy};
}

export function noteSharedIPad(runtime, deviceID, now = new Date().toISOString()) {
  const current = normalizeSessionRuntime(runtime, now);
  return {...current, shared_ipad:{last_device_id:deviceID || current.shared_ipad.last_device_id, last_seen:now}};
}

export function runtimeProjection(runtime, {connectedWayfolios = 0, connectedScreens = 0} = {}) {
  const current = normalizeSessionRuntime(runtime);
  const phoneReady = connectedWayfolios > 0;
  const sharedSelected = current.play_mode === PLAY_MODES.IPHONE_SHARED_IPAD;
  return {
    schema_version:current.schema_version,
    play_mode:current.play_mode,
    revision:current.revision,
    updated_at:current.updated_at,
    updated_by:current.updated_by,
    phone_controller_connected:phoneReady,
    shared_ipad_selected:sharedSelected,
    shared_ipad_connected:connectedScreens > 0,
    shared_ipad_status:!sharedSelected ? 'not_selected' : connectedScreens > 0 ? 'connected' : 'optional_offline',
    ready_to_play:phoneReady,
    selected_mode_ready:phoneReady && (!sharedSelected || connectedScreens > 0),
    continuity_policy:'journey_continues_when_shared_ipad_disconnects',
  };
}
