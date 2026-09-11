const role = document.body.dataset.role;
const socket = new WebSocket(`ws://${location.host}/session`);
const byId = id => document.getElementById(id);
let tableReconnectTimer = null;
let pendingRoll = null;
let pendingRollSubmission = null;
let rollRetryTimer = null;
let latestPresentationState = null;
let pendingVisual = null;
let sharedActorID = null;
let resolvedSceneAssetKey = '';
let pendingSceneAssetKey = '';
let latestSceneAssetKey = '';
let resolvedEncounterAssetKey = '';
let journeyLive = false;
let sessionRuntime = null;

function sharedScreenDeviceID() {
  if (role !== 'screen') return '';
  const key = 'wayfolio.shared.device-id';
  let value = localStorage.getItem(key);
  if (!value) { value = clientEventID(); localStorage.setItem(key, value); }
  return value;
}

// Local-network iPads load the Host over plain HTTP, where WebKit does not
// expose crypto.randomUUID(). Delivery IDs must therefore have a safe fallback.
function clientEventID() {
  const secureUUID = globalThis.crypto?.randomUUID?.();
  if (secureUUID) return secureUUID;
  return `wf-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}-${Math.random().toString(36).slice(2, 8)}`;
}

// The legacy DM markup predates explicit form labels. Keep the private host
// keyboard- and screen-reader-ready without changing its established layout.
if (role === 'dm') {
  byId('title-input')?.setAttribute('aria-label', 'Scene title');
  byId('text-input')?.setAttribute('aria-label', 'Scene description');
  byId('dialogue-text')?.setAttribute('aria-label', 'Dialogue to speak on the shared screen');
}
if (role === 'screen') {
  byId('audio-status')?.setAttribute('role', 'status');
  byId('audio-status')?.setAttribute('aria-live', 'polite');
}

function renderCampaignRegistryStatus(status, reconciliation) {
  if (role !== 'dm' || !status) return;
  let panel = byId('campaign-registry-status');
  if (!panel) {
    panel = document.createElement('section');
    panel.id = 'campaign-registry-status';
    panel.className = 'status';
    (byId('dm-system-slot') || byId('dm-actions')?.parentElement)?.append(panel);
  }
  const unresolved = reconciliation?.unresolved_fields || status.unresolved_fields || [];
  panel.innerHTML = `<strong>Shared campaign state · ${status.sync_status.replaceAll('_', ' ')}</strong><br>`
    + `<span>${status.cutover_complete ? 'Campaign State & Registry is the live source.'
      : `Safe first-sync preview complete. ${unresolved.length} authoritative field${unresolved.length === 1 ? '' : 's'} still need confirmation; the existing campaign remains live until then.`}</span>`;
}

function renderSharedActorPicker(catalog = []) {
  if (role !== 'screen' || !byId('action-panel')) return;
  let wrapper = byId('shared-actor-picker');
  if (!wrapper) {
    wrapper = document.createElement('label'); wrapper.id = 'shared-actor-picker'; wrapper.className = 'shared-actor-picker';
    wrapper.innerHTML = '<span>Who is speaking or acting?</span><select id="shared-actor"></select>';
    byId('action-text')?.before(wrapper);
    byId('shared-actor').addEventListener('change', event => { sharedActorID = event.target.value || null; });
  }
  const available = catalog.filter(character => character.connected);
  const select = byId('shared-actor'); select.replaceChildren();
  for (const character of available) {
    const option = document.createElement('option'); option.value = character.id; option.textContent = character.name;
    select.append(option);
  }
  sharedActorID = available.some(character => character.id === sharedActorID) ? sharedActorID : available[0]?.id || null;
  select.value = sharedActorID || '';
  wrapper.hidden = available.length <= 1;
}

function renderSharedVisual(visual) {
  if (role !== 'screen' || !visual?.url) return;
  let figure = byId('scene-visual');
  if (!figure) {
    figure = document.createElement('figure');
    figure.id = 'scene-visual'; figure.className = 'scene-visual';
    figure.innerHTML = '<img id="scene-visual-image" alt="Approved illustration for the current scene"><video id="scene-overlay-video" class="scene-overlay-video" muted loop playsinline hidden></video><div class="atmosphere-overlay" aria-hidden="true"><i></i><i></i><i></i><i></i><i></i></div><figcaption id="scene-visual-title"></figcaption>';
    document.querySelector('.panel')?.prepend(figure);
  }
  byId('scene-visual-image').src = `${visual.url}?v=${encodeURIComponent(visual.reviewed_at || visual.id)}`;
  byId('scene-visual-title').textContent = visual.title || 'Current scene';
  figure.hidden = false;
}

function setSharedStageState(state, message = '') {
  if (role !== 'screen') return;
  document.body.dataset.stageState = state || 'exploration';
  const status = byId('stage-status');
  if (!status) return;
  status.textContent = message;
  status.hidden = !message;
}

async function resolveManifestSceneVisual(scene = {}) {
  if (role !== 'screen') return;
  const sceneTitle = String(scene.scene_title || '');
  const locationID = String(scene.location_id || '');
  const sceneContextID = String(scene.scene_context_id || 'main_interior');
  if (!sceneTitle && !locationID) return;
  const requestKey = `${locationID}|${sceneContextID}|${sceneTitle}`.trim().toLowerCase();
  if (!requestKey || requestKey === resolvedSceneAssetKey || requestKey === pendingSceneAssetKey) return;
  latestSceneAssetKey = requestKey;
  pendingSceneAssetKey = requestKey;
  const query = new URLSearchParams({subject_type:'LOCATION', asset_role:'SHARED_IPAD_LOCATION_BACKGROUND',
    subject_id:locationID, scene_context_id:sceneContextID, audience:'shared_screen',
    knowledge_scope:String(scene.knowledge_scope || 'public'),
    fallback:'neutral_luminous_ledger'});
  try {
    const response = await fetch(`/api/assets/resolve?${query}`, {cache:'no-store'});
    const asset = await response.json();
    if (response.ok && ['ready','last_known_good'].includes(asset.state) && asset.url && latestSceneAssetKey === requestKey) {
      renderSharedVisual({...asset, id:asset.asset_id, title:asset.display_name || sceneTitle,
        reviewed_at:`${asset.version}-${asset.revision}`});
      resolvedSceneAssetKey = requestKey;
      setSharedStageState('exploration');
    }
    void resolveManifestSceneOverlay(scene, requestKey);
  } catch {
    // Asset transport is deliberately non-blocking. The Luminous Ledger surface remains usable.
  } finally {
    if (pendingSceneAssetKey === requestKey) pendingSceneAssetKey = '';
    if (resolvedSceneAssetKey !== requestKey && latestSceneAssetKey === requestKey) {
      setTimeout(() => { if (latestSceneAssetKey === requestKey) void resolveManifestSceneVisual(scene); }, 1200);
    }
  }
}

async function resolveManifestSceneOverlay(scene, requestKey) {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  const query = new URLSearchParams({subject_type:'LOCATION', asset_role:'SHARED_IPAD_ANIMATED_OVERLAY',
    subject_id:String(scene.location_id || ''), scene_context_id:String(scene.scene_context_id || 'main_interior'),
    audience:'shared_screen', knowledge_scope:String(scene.knowledge_scope || 'public'), fallback:'code_atmosphere'});
  try {
    const response = await fetch(`/api/assets/resolve?${query}`, {cache:'no-store'});
    const asset = await response.json();
    const video = byId('scene-overlay-video');
    if (response.ok && ['ready','last_known_good'].includes(asset.state) && asset.url && video && resolvedSceneAssetKey === requestKey) {
      video.src = asset.url; video.hidden = false; await video.play().catch(() => {});
    }
  } catch { setSharedStageState('fallback', 'The scene remains available while its illustration reconnects.'); }
}

function showVisualDraft(visual) {
  pendingVisual = visual || null;
  const review = byId('visual-review');
  if (!review) return;
  review.hidden = !visual;
  if (visual) {
    byId('visual-preview').src = `${visual.url}?v=${encodeURIComponent(visual.created_at || visual.id)}`;
    byId('visual-review-title').textContent = `${visual.title || 'Scene visual'} · private draft`;
  }
}

async function visualRequest(path, body) {
  const response = await fetch(path, {method:'POST', headers:{'content-type':'application/json'}, body:JSON.stringify(body)});
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error || 'The visual studio could not complete that request.');
  return payload;
}

async function initializeVisualStudio() {
  if (role !== 'dm') return;
  const studio = document.createElement('section');
  studio.id = 'visual-studio'; studio.className = 'visual-studio';
  studio.innerHTML = '<div class="visual-studio-heading"><div><span class="eyebrow">Private draft room</span><h2>Shared Scene Visual</h2></div><span id="visual-model" class="visual-model"></span></div><p class="quiet">Describe what the table should see. Character identity locks and approved references are applied automatically. Nothing reaches the shared screen until you approve it.</p><label class="field-label" for="visual-title">Scene title</label><input id="visual-title" value="The Lantern Road"><label class="field-label" for="visual-prompt">What should the illustration show?</label><textarea id="visual-prompt" rows="5" placeholder="Renn, Soren, and Lupin stand beneath the old bridge as blue motes form a path through the roots."></textarea><fieldset><legend>Characters visible in this scene</legend><div id="visual-characters" class="visual-character-grid"></div></fieldset><button id="generate-visual">Generate private draft</button><p id="visual-status" class="quiet">Checking the visual studio…</p><article id="visual-review" hidden><img id="visual-preview" alt="Private visual draft awaiting DM review"><h3 id="visual-review-title">Draft awaiting review</h3><div class="visual-review-actions"><button id="approve-visual">Approve for shared screen</button><button id="regenerate-visual" class="secondary">Generate another</button><button id="reject-visual" class="danger">Reject draft</button></div></article>';
  (byId('dm-studio-slot') || byId('dm-actions')?.parentElement)?.append(studio);
  try {
    const response = await fetch('/api/visuals/status', {cache:'no-store'});
    const status = await response.json();
    if (!response.ok) throw new Error(status.error);
    byId('visual-model').textContent = status.model;
    byId('visual-status').textContent = status.configured
      ? 'Ready. Each generation uses the connected OpenAI API account.'
      : 'AI is not connected. Open Game Screens → AI DM Setup before generating.';
    byId('generate-visual').disabled = !status.configured;
    const choices = byId('visual-characters');
    for (const identity of status.identities) {
      const label = document.createElement('label');
      label.innerHTML = `<input type="checkbox" value="${identity.character_id}"><span><strong>${identity.name}</strong><small>${identity.reference_count ? `${identity.reference_count} approved reference${identity.reference_count === 1 ? '' : 's'}` : 'description locked'}</small></span>`;
      choices.append(label);
    }
    showVisualDraft(status.pending);
  } catch (error) { byId('visual-status').textContent = error.message; byId('generate-visual').disabled = true; }

  const generate = async () => {
    const button = byId('generate-visual'); button.disabled = true;
    byId('visual-status').textContent = 'Creating a private draft. This can take a few minutes…';
    try {
      const characterIDs = [...document.querySelectorAll('#visual-characters input:checked')].map(input => input.value);
      const payload = await visualRequest('/api/visuals/generate', {title:byId('visual-title').value, prompt:byId('visual-prompt').value, character_ids:characterIDs});
      showVisualDraft(payload.visual); byId('visual-status').textContent = 'Draft ready. Review it below before sharing.';
    } catch (error) { byId('visual-status').textContent = error.message; }
    finally { button.disabled = false; }
  };
  byId('generate-visual').addEventListener('click', generate);
  byId('regenerate-visual').addEventListener('click', generate);
  for (const [id, action] of [['approve-visual','approve'], ['reject-visual','reject']]) {
    byId(id).addEventListener('click', async () => {
      if (!pendingVisual) return;
      try {
        const payload = await visualRequest('/api/visuals/review', {visual_id:pendingVisual.id, action});
        showVisualDraft(null);
        byId('visual-status').textContent = action === 'approve' ? 'Approved and displayed on the shared screen.' : 'Draft rejected. Nothing was shared.';
      } catch (error) { byId('visual-status').textContent = error.message; }
    });
  }
}

if (role === 'dm' && !document.querySelector('.dm-header-links')) {
  const screensButton = document.createElement('button');
  screensButton.textContent = 'Game Screens';
  screensButton.className = 'secondary';
  screensButton.style.cssText = 'position:fixed;top:14px;right:14px;z-index:20;width:auto;padding:10px 16px;background:#06151ef2';
  screensButton.addEventListener('click', () => window.open('/launcher', 'wayfolio-launcher'));
  document.body.append(screensButton);
}

void initializeVisualStudio();

function renderAction(action) {
  const target = role === 'dm' ? byId('dm-actions') : byId('public-actions');
  if (!target || target.querySelector(`[data-action-id="${action.id || action.action_id}"]`)) return;
  const item = document.createElement('article');
  item.className = `action ${action.visibility}`;
  item.dataset.actionId = action.id || action.action_id;
  const label = document.createElement('strong');
  label.textContent = `${action.author} · ${action.visibility === 'private' ? 'Private to DM' : 'Public'}`;
  const content = document.createElement('p');
  content.textContent = action.text;
  item.append(label, content);
  target.prepend(item);
}

function showRoll(roll) {
  pendingRoll = roll;
  const panel = byId('roll-panel');
  if (!panel || !roll) return;
  if (!byId('roll-details')) {
    panel.querySelector('h2')?.insertAdjacentHTML('beforebegin', '<div class="roll-heading"><span id="roll-kind" class="eyebrow"></span><span id="roll-visibility" class="roll-badge"></span></div>');
    byId('roll-request')?.insertAdjacentHTML('afterend', '<dl id="roll-details" class="roll-details"></dl><p id="roll-stakes" class="roll-stakes"></p>');
    const legacyInput = byId('physical-die');
    if (legacyInput) { const dice = document.createElement('div'); dice.id = 'physical-dice'; dice.className = 'physical-dice'; legacyInput.replaceWith(dice); }
  }
  panel.hidden = false;
  const dieType = Number(roll.die_type || 20);
  const selection = ['advantage','disadvantage'].includes(roll.selection) ? roll.selection : 'normal';
  const diceNeeded = selection === 'normal' ? Number(roll.dice_count || 1) : 2;
  const opposed = roll.opposed?.name;
  const modifier = Number(roll.modifier || 0);
  const fixedBonus = Number(roll.fixed_bonus || 0);
  byId('roll-kind').textContent = opposed ? 'Opposed check' : `${selection} check`;
  byId('roll-visibility').textContent = roll.secret ? 'Host secret' : 'Public roll';
  byId('roll-request').textContent = `${roll.playerName}: “${roll.choice}”`;
  const formula = `${diceNeeded > 1 ? `${diceNeeded}d${dieType} (${selection === 'advantage' ? 'keep highest' : selection === 'disadvantage' ? 'keep lowest' : 'add all'})` : `d${dieType}`} ${modifier >= 0 ? '+' : '−'} ${Math.abs(modifier)}${fixedBonus ? ` ${fixedBonus >= 0 ? '+' : '−'} ${Math.abs(fixedBonus)}` : ''}`;
  byId('roll-details').innerHTML = `<div><dt>Ability or skill</dt><dd>${roll.skill}</dd></div><div><dt>Roll</dt><dd>${formula}</dd></div><div><dt>${opposed ? 'Opponent' : 'Difficulty'}</dt><dd>${opposed || `DC ${roll.dc}`}</dd></div><div><dt>Ruling locked</dt><dd>${roll.ruling_locked_at ? 'Before dice' : 'Legacy request'}</dd></div>`;
  const sources = selection === 'advantage' ? roll.advantage_sources : selection === 'disadvantage' ? roll.disadvantage_sources : [];
  byId('roll-stakes').textContent = `${roll.stakes || 'The outcome changes the situation.'}${sources?.length ? ` ${selection[0].toUpperCase() + selection.slice(1)}: ${sources.join('; ')}.` : ''}`;
  byId('digital-roll').textContent = `Roll ${diceNeeded > 1 ? `${diceNeeded}d${dieType}` : `d${dieType}`} digitally`;
  const dice = byId('physical-dice');
  dice.replaceChildren();
  for (let index = 0; index < diceNeeded; index += 1) {
    const input = document.createElement('input');
    input.className = 'physical-die'; input.type = 'number'; input.min = '1'; input.max = String(dieType);
    input.placeholder = diceNeeded > 1 ? `Physical d${dieType} — die ${index + 1}` : `Physical d${dieType} result`;
    input.setAttribute('aria-label', input.placeholder); dice.append(input);
  }
  byId('roll-error').textContent = '';
  setRollControlsEnabled(true);
}

function setRollControlsEnabled(enabled) {
  if (byId('digital-roll')) byId('digital-roll').disabled = !enabled;
  if (byId('physical-roll')) byId('physical-roll').disabled = !enabled;
  document.querySelectorAll('.physical-die').forEach(input => { input.disabled = !enabled; });
}

function setRollStatus(message) {
  if (byId('roll-error')) byId('roll-error').textContent = message || '';
}

function reconnectSharedTable(message = 'Reconnecting to the Wayfolio DM…') {
  if (role !== 'screen') return;
  setRollControlsEnabled(false);
  setRollStatus(message);
  setSharedStageState('reconnecting', message);
  if (tableReconnectTimer) return;
  tableReconnectTimer = setTimeout(() => location.reload(), 700);
}

function finishPendingRollSubmission(message) {
  if (rollRetryTimer) clearTimeout(rollRetryTimer);
  rollRetryTimer = null;
  pendingRollSubmission = null;
  if (message) setRollStatus(message);
}

function transmitPendingRoll(attempt = 1) {
  if (!pendingRollSubmission) return;
  if (socket.readyState !== WebSocket.OPEN) {
    finishPendingRollSubmission('');
    reconnectSharedTable('The table connection paused. Reconnecting—your roll is still waiting.');
    return;
  }
  socket.send(JSON.stringify(pendingRollSubmission));
  setRollStatus(attempt === 1 ? 'Sending roll to the Wayfolio DM…' : 'Confirming roll with the Wayfolio DM…');
  if (rollRetryTimer) clearTimeout(rollRetryTimer);
  rollRetryTimer = setTimeout(() => {
    if (!pendingRollSubmission) return;
    if (attempt < 3) transmitPendingRoll(attempt + 1);
    else {
      setRollControlsEnabled(true);
      finishPendingRollSubmission('The roll was not confirmed. Reload this screen and try again; no second roll was recorded.');
    }
  }, 1800);
}

function submitRoll(mode, dice) {
  if (!pendingRoll || pendingRollSubmission) return;
  setRollControlsEnabled(false);
  setRollStatus('Preparing your roll…');
  pendingRollSubmission = {type:'roll_submit', roll_id:pendingRoll.id, mode,
    client_roll_submission_id:clientEventID(), ...(dice ? {dice} : {})};
  transmitPendingRoll();
}

socket.addEventListener('open', () => socket.send(JSON.stringify({type:'join', role, session_code:'HEMLOCK',
  ...(role === 'screen' ? {device_id:sharedScreenDeviceID()} : {})})));
socket.addEventListener('close', () => reconnectSharedTable());
socket.addEventListener('error', () => reconnectSharedTable('The table connection paused. Reconnecting…'));
window.addEventListener('pageshow', () => {
  if (role === 'screen' && socket.readyState > WebSocket.OPEN) reconnectSharedTable();
});
document.addEventListener('visibilitychange', () => {
  if (role === 'screen' && !document.hidden && socket.readyState !== WebSocket.OPEN) reconnectSharedTable();
});
function showStorytellerRuntime(status) {
  if (role !== 'screen' || !status) return;
  const node = byId('storyteller-runtime-status');
  const action = byId('action-public');
  const messages = {
    CONNECTING:'Connecting Storyteller…', GENERATING:'Storyteller is responding…',
    SLOW:'Storyteller is taking longer than expected…', RECONNECTING:'Storyteller unavailable. Reconnecting…',
    REAUTHORIZATION_REQUIRED:'Storyteller unavailable — waiting for host.',
    UNAVAILABLE:'Storyteller unavailable — waiting for host.', DISCONNECTED:'Storyteller unavailable — waiting for host.',
    BUDGET_PAUSED:'Live Storyteller paused — Local Play active.',
  };
  const message = messages[status.state] || '';
  node.hidden = !message; node.textContent = message;
  node.classList.toggle('failure', ['REAUTHORIZATION_REQUIRED','UNAVAILABLE','DISCONNECTED'].includes(status.state));
  if (action) action.disabled = ['CONNECTING','GENERATING','SLOW','RECONNECTING','REAUTHORIZATION_REQUIRED','UNAVAILABLE'].includes(status.state);
  if (status.state === 'BUDGET_PAUSED') {
    clearTimeout(showStorytellerRuntime.localPlayTimer);
    showStorytellerRuntime.localPlayTimer = setTimeout(() => { node.hidden = true; }, 4500);
  }
}
window.addEventListener('wayfolio-dialogue-status', event => {
  if (role === 'screen' && socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify({type:'presentation_ack', ...event.detail}));
  }
});

function clearCompletedTurnPresentation() {
  const result = byId('result');
  if (result) result.textContent = '';
  const choice = byId('choice');
  if (choice) choice.textContent = '';
  window.wayfolioAudio?.dismissDialogue();
}

socket.addEventListener('message', event => {
  const message = JSON.parse(event.data);
  if (role === 'screen' && ['joined','session_snapshot','scene_update'].includes(message.type)) setSharedStageState('exploration');
  if (message.session_runtime) {
    sessionRuntime = message.session_runtime;
    if (role === 'screen') document.body.dataset.sessionMode = sessionRuntime.play_mode;
  }
  if (message.storyteller_transport) showStorytellerRuntime(message.storyteller_transport);
  if (message.campaign_registry_status) {
    renderCampaignRegistryStatus(message.campaign_registry_status, message.first_shared_state_reconciliation);
  }
  if (role === 'screen' && byId('action-status')) {
    if (message.type === 'action_ack') byId('action-status').textContent = 'The Wayfolio DM is considering what happens next…';
    if (message.type === 'action_review_pending') byId('action-status').textContent = message.message;
    if (message.type === 'action_clarification') byId('action-status').textContent = message.message;
    if (message.type === 'choice_received') byId('action-status').textContent = message.message;
    if (message.type === 'error') byId('action-status').textContent = message.message;
    if (message.type === 'turn_committed' || message.type === 'scene_update') byId('action-status').textContent = '';
  }
  if (role === 'screen' && ['action_event', 'action_ack', 'turn_presentation_cleared'].includes(message.type)) {
    clearCompletedTurnPresentation();
  }
  if (role === 'screen' && message.type === 'dm_answer') {
    appendDMChat('dm', 'Wayfolio DM', message.answer);
    byId('dm-question-status').textContent = 'This conversation did not change the story.';
    byId('send-dm-question').disabled = false;
  }
  if (message.scene_title) {
    byId('scene-title').textContent = message.scene_title;
    void resolveManifestSceneVisual(message);
  }
  if (message.active_journey_title && byId('journey-name')) {
    byId('journey-name').textContent = message.active_journey_title;
  }
  if (message.scene_text) byId('scene-text').textContent = message.scene_text;
  if (role === 'dm' && typeof message.journey_live === 'boolean') {
    journeyLive = message.journey_live;
    const badge = byId('journey-state-badge');
    const toggle = byId('journey-toggle');
    if (badge) { badge.textContent = journeyLive ? 'Journey live' : 'Journey paused'; badge.classList.toggle('live', journeyLive); }
    if (toggle) { toggle.textContent = journeyLive ? 'Pause journey' : 'Resume journey'; toggle.disabled = false; }
  }
  if (message.players) {
    byId('players').textContent = message.players.length ? message.players.map(p => `${p.name}${p.connected ? ' • connected' : ' • assigned, offline'}`).join(' · ') : 'Waiting for Wayfolios…';
    if (role === 'dm') renderAssignments(message.players);
  }
  if (message.character_catalog) renderSharedActorPicker(message.character_catalog);
  if (message.join_info && role === 'screen') {
    let card = byId('join-card');
    if (!card) {
      card = document.createElement('section');
      card.id = 'join-card';
      card.className = 'join-card';
      card.innerHTML = '<img id="join-qr" alt="Scan to join the Wayfolio session" style="width:150px;border-radius:12px"><div><span>Join this adventure</span><strong id="join-code"></strong><small id="join-characters"></small></div><div><span>Wayfolio host</span><strong id="join-host"></strong></div>';
      card.style.cssText = 'display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:18px;margin:18px 0 26px;padding:18px 24px;border:1px solid #72dce5;border-radius:18px;background:#06151ecc';
      for (const column of card.children) column.style.cssText = 'display:flex;flex-direction:column;gap:5px';
      for (const label of card.querySelectorAll('span')) label.style.cssText = 'color:#72dce5;text-transform:uppercase;letter-spacing:.14em;font-size:13px';
      for (const value of card.querySelectorAll('strong')) value.style.cssText = 'color:#f5e7bd;font-size:clamp(20px,2.5vw,30px);overflow-wrap:anywhere';
      document.querySelector('.panel')?.before(card);
    }
    byId('join-code').textContent = message.join_info.session_code;
    byId('join-host').textContent = message.join_info.host;
    byId('join-qr').src = message.join_info.qr_url;
    if (message.character_catalog && byId('join-characters')) {
      byId('join-characters').textContent = message.character_catalog.map(character =>
        `${character.name}: ${character.connected ? 'connected' : character.assigned ? 'reserved' : 'available'}`).join(' · ');
    }
  }
  if (message.last_choice && byId('choice')) {
    const actor = message.last_choice.player_name
      || message.players?.find(player => player.id === message.last_choice.player_id)?.name
      || message.last_choice.player_id || 'The player';
    byId('choice').textContent = `${actor} chose: ${message.last_choice.choice}`;
  }
  if (message.last_result && byId('result')) {
    const result = message.last_result;
    byId('result').textContent = `${result.player_name}: ${result.detail} — ${result.succeeded ? 'success' : 'complication'}`;
    if (byId('roll-panel')) byId('roll-panel').hidden = true;
    finishPendingRollSubmission('');
    setSharedStageState('result');
  }
  if (role === 'screen' && message.type === 'session_snapshot' && !message.last_result) {
    const result = byId('result');
    if (result) result.textContent = '';
  }
  if (message.type === 'roll_ack') {
    setRollControlsEnabled(false);
    finishPendingRollSubmission('Roll received. Resolving the outcome…');
  }
  if (message.type === 'roll_requested') showRoll(message.roll);
  if (message.pending_roll) showRoll(message.pending_roll);
  if (message.type === 'action_event') renderAction(message);
  if (message.action_log && role === 'dm') message.action_log.slice().reverse().forEach(renderAction);
  if (message.presentation_state) latestPresentationState = message.presentation_state;
  if (message.current_visual) renderSharedVisual(message.current_visual);
  if (message.current_dialogue && role === 'screen') window.wayfolioAudio?.restoreDialogue(message.current_dialogue);
  else if (role === 'screen' && message.type === 'session_snapshot') window.wayfolioAudio?.dismissDialogue();
  if (message.type === 'visual_update') {
    renderSharedVisual(message.visual);
    setSharedStageState('manifestation', 'A new scene has manifested.');
    setTimeout(() => setSharedStageState('exploration'), 2400);
  }
  if (role === 'dm' && message.pending_visual) showVisualDraft(message.pending_visual);
  if (message.story_state && byId('story-status')) {
    byId('story-status').textContent = `Chapter checkpoint: ${String(message.story_state.checkpoint || 'ready').replaceAll('_', ' ')}`;
  }
  if (message.type === 'session_snapshot') renderEncounter(message.active_encounter || null);
  else if (message.active_encounter) renderEncounter(message.active_encounter);
  if (message.type === 'encounter_reveal' && byId('encounter-reveal')) {
    byId('encounter-reveal').hidden = false;
    byId('encounter-reveal').textContent = `${message.creature.name} · ${message.creature.reveal_percent}% discovered — ${message.creature.summary}`;
    setSharedStageState('manifestation');
  }
  if (message.type === 'presentation_event' && role === 'screen') {
    if (message.event?.type === 'dialogue') setSharedStageState('dialogue');
    window.wayfolioAudio?.handle(message.event);
  }
  if (message.type === 'assignment_released' && byId('assignment-status')) {
    byId('assignment-status').textContent = `${message.player_name || 'Character'} is available for a Wayfolio to join.`;
  }
  if (role === 'dm' && message.type === 'journey_paused') {
    const status = byId('journey-control-status');
    if (status) status.textContent = 'Paused safely. The scene, encounter, and pending roll are saved.';
  }
  if (role === 'dm' && message.type === 'journey_continued') {
    const status = byId('journey-control-status');
    if (status) status.textContent = 'Journey resumed. The shared screen is live.';
  }
});

function renderAssignments(players) {
  let panel = byId('player-assignments');
  if (!panel) {
    panel = document.createElement('section');
    panel.id = 'player-assignments';
    panel.className = 'audio-controls';
    panel.innerHTML = '<h2>Wayfolio assignments</h2><div id="assignment-list"></div><p id="assignment-status" class="quiet">Release an assignment only when a player changed or reinstalled their device.</p>';
    (byId('dm-party-slot') || byId('dm-actions')?.parentElement)?.append(panel);
  }
  const list = byId('assignment-list');
  list.replaceChildren();
  for (const player of players) {
    const row = document.createElement('div');
    row.style.cssText = 'display:grid;grid-template-columns:1fr minmax(180px,260px);gap:12px;align-items:center;margin:10px 0';
    const label = document.createElement('strong');
    label.textContent = `${player.name} · ${player.connected ? 'connected' : 'offline'}`;
    const button = document.createElement('button');
    button.className = 'secondary';
    button.textContent = `Release ${player.name}`;
    button.addEventListener('click', () => socket.send(JSON.stringify({type:'dm_release_player', player_id:player.id})));
    row.append(label, button);
    list.append(row);
  }
  if (!players.length) list.textContent = 'No Wayfolios are currently assigned.';
}

function renderEncounter(encounter) {
  let panel = byId('encounter-state');
  if (!panel) return;
  const combatants = Array.isArray(encounter?.combatants) ? encounter.combatants : [];
  const isRenderable = encounter && typeof encounter.name === 'string' && encounter.name.trim() && combatants.length > 0;
  if (!isRenderable) {
    panel.hidden = true;
    panel.replaceChildren();
    return;
  }
  if (!panel) {
    panel = document.createElement('section'); panel.id = 'encounter-state'; panel.className = 'audio-controls';
    byId('action-panel')?.before(panel);
  }
  panel.hidden = false;
  const active = combatants.find(value => value.id === encounter.active_combatant_id);
  panel.innerHTML = `<img id="encounter-art" class="encounter-art" alt="" hidden><div class="encounter-copy"><h2>${encounter.name}</h2><p class="status">${encounter.status === 'resolved' ? `Resolved · ${encounter.outcome}` : `Round ${encounter.round} · ${active?.name || 'Preparing'} acts`}</p></div>`;
  for (const combatant of combatants) {
    const line = document.createElement('p'); line.className = 'quiet';
    const health = combatant.hp_visibility === false
      ? (combatant.public_status || 'condition unknown')
      : `${combatant.hp}/${combatant.maximum_hp} HP`;
    line.textContent = `${combatant.name}: ${health}${combatant.conditions?.length ? ` · ${combatant.conditions.join(', ')}` : ''}`;
    panel.append(line);
  }
  void resolveEncounterArt(encounter, combatants);
}

async function resolveEncounterArt(encounter, combatants) {
  const creature = combatants.find(value => value.kind !== 'player' && value.kind !== 'companion');
  if (!creature?.id) return;
  const key = `${encounter?.name}|${creature.id}`;
  if (key === resolvedEncounterAssetKey) return;
  resolvedEncounterAssetKey = key;
  const subjectID = `CREATURE_${String(creature.id).toUpperCase().replaceAll('-', '_')}`;
  const query = new URLSearchParams({subject_type:'CREATURE', subject_id:subjectID,
    asset_role:'CREATURE_ENCOUNTER_ART', audience:'shared_screen', knowledge_scope:'public',
    fallback:'approved_native_creature_reference'});
  try {
    const response = await fetch(`/api/assets/resolve?${query}`, {cache:'no-store'});
    const asset = await response.json();
    const image = byId('encounter-art');
    if (response.ok && ['ready','last_known_good'].includes(asset.state) && asset.url && image && key === resolvedEncounterAssetKey) {
      image.src = asset.url; image.alt = `Approved illustration of ${creature.name}`; image.hidden = false;
    }
  } catch {}
}

if (role === 'screen') {
  const tools = byId('screen-tools');
  const menu = byId('screen-menu');
  const setToolsOpen = open => {
    tools.hidden = !open;
    menu?.setAttribute('aria-expanded', String(open));
  };
  menu?.addEventListener('click', () => setToolsOpen(tools.hidden));
  byId('close-screen-tools')?.addEventListener('click', () => setToolsOpen(false));
  byId('open-launcher')?.addEventListener('click', () => window.location.assign('/launcher'));
  const dmPanel = byId('dm-conversation');
  const askDM = byId('ask-dm');
  const setDMOpen = open => {
    dmPanel.hidden = !open;
    askDM?.setAttribute('aria-expanded', String(open));
    if (open) byId('dm-question')?.focus();
  };
  askDM?.addEventListener('click', () => setDMOpen(dmPanel.hidden));
  byId('close-dm-conversation')?.addEventListener('click', () => setDMOpen(false));
  byId('send-dm-question')?.addEventListener('click', () => {
    const question = byId('dm-question').value.trim();
    if (!question) return;
    appendDMChat('user', 'You', question);
    byId('dm-question').value = '';
    byId('dm-question-status').textContent = 'The Wayfolio DM is checking the campaign record…';
    byId('send-dm-question').disabled = true;
    socket.send(JSON.stringify({type:'dm_question', question}));
  });
}

function appendDMChat(kind, speaker, message) {
  const log = byId('dm-chat-log');
  if (!log) return;
  const item = document.createElement('article'); item.className = `dm-chat-message ${kind}`;
  const name = document.createElement('strong'); name.textContent = speaker;
  const copy = document.createElement('p'); copy.textContent = message;
  item.append(name, copy); log.append(item); log.scrollTop = log.scrollHeight;
}

if (byId('enable-audio')) {
  byId('enable-audio').addEventListener('click', async () => {
    await window.wayfolioAudio.enable();
    await window.wayfolioAudio.restore(latestPresentationState);
    byId('enable-audio').textContent = 'Audio enabled';
    byId('enable-audio').disabled = true;
  });
  document.querySelectorAll('[data-bus-volume]').forEach(input => {
    input.value = window.wayfolioAudio.busLevels[input.dataset.busVolume];
    input.addEventListener('input', () => window.wayfolioAudio.setBusVolume(input.dataset.busVolume, input.value));
  });
  document.querySelectorAll('[data-bus-muted]').forEach(input => {
    input.checked = window.wayfolioAudio.busMuted[input.dataset.busMuted];
    input.addEventListener('change', () => window.wayfolioAudio.setBusMuted(input.dataset.busMuted, input.checked));
  });
}

function submitTableAction(visibility) {
  const input = byId('action-text');
  const text = input?.value.trim();
  if (!text) return;
  socket.send(JSON.stringify({type:'action_submit', client_action_id:clientEventID(),
    player_id:sharedActorID || 'table', author:byId('shared-actor')?.selectedOptions?.[0]?.textContent || 'At the table', text, visibility}));
  input.value = '';
  byId('action-status').textContent = visibility === 'private'
    ? 'Sent privately to the DM.' : 'Sending your action to the Wayfolio DM…';
}

if (byId('action-public')) {
  byId('action-public').addEventListener('click', () => submitTableAction('public'));
  byId('action-private')?.addEventListener('click', () => submitTableAction('private'));
}

if (byId('digital-roll')) {
  byId('digital-roll').addEventListener('click', () => {
    if (pendingRoll) submitRoll('digital');
  });
  byId('physical-roll').addEventListener('click', () => {
    const dieType = Number(pendingRoll?.die_type || 20);
    const dice = [...document.querySelectorAll('.physical-die')].map(input => Number(input.value));
    if (pendingRoll && dice.length && dice.every(die => Number.isInteger(die) && die >= 1 && die <= dieType)) {
      submitRoll('physical', dice);
    } else {
      setRollStatus(`Enter every physical d${dieType} result, from 1 through ${dieType}.`);
    }
  });
}

if (role === 'dm') {
  const present = event => socket.send(JSON.stringify({type:'dm_presentation', event}));
  byId('journey-toggle')?.addEventListener('click', () => {
    const toggle = byId('journey-toggle');
    toggle.disabled = true;
    byId('journey-control-status').textContent = journeyLive ? 'Pausing and saving…' : 'Resuming the table…';
    socket.send(JSON.stringify({type:journeyLive ? 'dm_journey_pause' : 'dm_journey_continue'}));
  });
  byId('start-encounter')?.addEventListener('click', () => socket.send(JSON.stringify({type:'dm_start_encounter'})));
  byId('start-monster-encounter')?.addEventListener('click', () => socket.send(JSON.stringify({type:'dm_start_monster_encounter'})));
  byId('publish').addEventListener('click', () => socket.send(JSON.stringify({type:'dm_scene', scene_title:byId('title-input').value, scene_text:byId('text-input').value})));
  byId('prompt').addEventListener('click', () => socket.send(JSON.stringify({type:'dm_prompt', player_id:'renn', title:'Renn — what do you do?', message:'The motes gather around the bridge rail.', choices:['Reach toward the motes','Study them from a distance','Call the party closer'], skill:byId('skill').value, dc:byId('dc').value, modifier:byId('modifier').value})));
  document.querySelectorAll('[data-sfx]').forEach(button => button.addEventListener('click', () => present({type:'sound_effect', cue:button.dataset.sfx})));
  document.querySelectorAll('[data-ambience]').forEach(button => button.addEventListener('click', () => {
    const cue = button.dataset.ambience;
    present({type:'ambience', action:cue ? 'play' : 'stop', ...(cue ? {cue, volume:0.5} : {}), fade_duration:1.5});
  }));
  document.querySelectorAll('[data-ambience-profile]').forEach(button => button.addEventListener('click', () => {
    const profile = button.dataset.ambienceProfile;
    present({type:'ambience_scene', action:profile ? 'play' : 'stop', ...(profile ? {profile} : {}), fade_duration:1.5});
  }));
  document.querySelectorAll('[data-music]').forEach(button => button.addEventListener('click', () => {
    const cue = button.dataset.music;
    present({type:'music', action:cue ? 'play' : 'stop', ...(cue ? {cue, volume:0.42, intensity:0.3} : {}), fade_duration:2});
  }));
  document.querySelectorAll('[data-creature-preset]').forEach(button => button.addEventListener('click', () => {
    present(JSON.parse(button.dataset.creaturePreset));
  }));
  byId('speak-dialogue').addEventListener('click', () => present({
    type:'dialogue', line_id:clientEventID(), speaker_id:byId('speaker-id').value || 'narrator',
    text:byId('dialogue-text').value, performance:byId('performance').value,
    priority:'normal', interrupt:'queue', caption:true,
  }));
  byId('stop-all-audio').addEventListener('click', () => present({type:'audio_control', action:'stop_all', fade_duration:0.25}));
}
