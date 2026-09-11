const socket = new WebSocket(`ws://${location.host}/session`);
const byId = id => document.getElementById(id);
let proposal = null;
let consequence = null;
let joined = false;
let journeyLive = false;
let journeyHasHistory = false;
let presentCount = 0;

socket.addEventListener('open', () => socket.send(JSON.stringify({type:'join', role:'dm', session_code:'HEMLOCK'})));
socket.addEventListener('message', event => {
  const message = JSON.parse(event.data);
  if (message.type === 'joined') {
    joined = true;
    byId('journey-status').textContent = 'Central game connected. Connect at least one Wayfolio to begin.';
    updateStartButton();
  }
  if (message.world_state) byId('world-state').textContent = JSON.stringify(message.world_state, null, 2);
  if (message.character_catalog) renderPresence(message.character_catalog);
  if (message.character_lifecycle) renderPartyState(message.character_lifecycle);
  if (message.asset_diagnostics) renderAssetDiagnostics(message.asset_diagnostics);
  if (typeof message.journey_has_history === 'boolean') journeyHasHistory = message.journey_has_history;
  if (typeof message.journey_live === 'boolean') {
    journeyLive = message.journey_live;
    if (journeyLive) byId('journey-status').textContent = 'Journey active. Waiting for a player to declare an action from their Wayfolio.';
    else if (journeyHasHistory) byId('journey-status').textContent = `Saved at “${message.scene_title}.” Continue when the players are ready.`;
    updateStartButton();
  }
  if (message.review_log) renderLog(message.review_log);
  if (message.review_proposal) showProposal(message.review_proposal);
  if (message.consequence_proposal) showConsequence(message.consequence_proposal);
  if (message.type === 'review_proposal') showProposal(message.proposal);
  if (message.type === 'consequence_proposal') showConsequence(message.consequence);
  if (message.type === 'turn_committed') showConsequence(null);
  if (message.type === 'party_member_introduced') {
    byId('party-state-status').textContent = `${message.name} is now eligible for public party presentation.`;
  }
  if (message.type === 'review_status') byId('review-status').textContent = message.message;
  if (['open_play_started', 'journey_started', 'journey_continued'].includes(message.type)) {
    journeyLive = true;
    const verb = message.type === 'journey_started' ? 'started' : 'continued';
    byId('journey-status').textContent = `Journey ${verb} with ${message.players.join(', ')}. Players may now declare actions.`;
    updateStartButton();
  }
  if (message.type === 'error') {
    byId('journey-status').textContent = message.message;
    updateStartButton();
  }
});

socket.addEventListener('close', () => {
  joined = false;
  byId('journey-status').textContent = 'Central game disconnected. Return to the launcher and restart Wayfolio.';
  updateStartButton();
});

function updateStartButton() {
  const button = byId('start-open-play');
  button.disabled = !joined || presentCount === 0 || journeyLive;
  button.textContent = journeyLive ? 'Journey Is Active'
    : presentCount === 0 ? 'Waiting for a Wayfolio'
    : journeyHasHistory ? 'Continue Current Journey' : 'Start New Journey';
}

function stateLabel(value) {
  return String(value || 'unknown').replaceAll('_', ' ');
}

function renderPartyState(lifecycle) {
  const values = Object.values(lifecycle);
  byId('party-state-list').replaceChildren(...values.map(value => {
    const row = document.createElement('article'); row.className = 'presence-row';
    const identity = document.createElement('div');
    const name = document.createElement('strong'); name.textContent = value.character_name || value.character_id;
    const detail = document.createElement('span');
    detail.textContent = `${stateLabel(value.party_membership)} party · ${stateLabel(value.reveal_state)} · ${stateLabel(value.playability)} · ${stateLabel(value.scene_presence)}`;
    identity.append(name, detail); row.append(identity);
    if (value.reveal_state === 'pending_introduction') {
      const button = document.createElement('button'); button.type = 'button'; button.className = 'secondary';
      button.textContent = 'Introduce in story';
      button.addEventListener('click', () => socket.send(JSON.stringify({type:'dm_introduce_party_member', character_id:value.character_id})));
      row.append(button);
    } else {
      const state = document.createElement('span'); state.className = 'presence-state';
      state.textContent = value.reveal_state === 'introduced' ? 'Publicly eligible' : 'Kept private'; row.append(state);
    }
    return row;
  }));
}

function renderAssetDiagnostics(values) {
  byId('asset-diagnostics').replaceChildren(...values.map(value => {
    const row = document.createElement('article'); row.className = 'presence-row';
    const identity = document.createElement('div');
    const name = document.createElement('strong'); name.textContent = value.name;
    const detail = document.createElement('span');
    detail.textContent = `Local ${value.local_version ?? 'missing'} · approved ${value.approved_version ?? 'unknown'} · ${stateLabel(value.update_state)}`;
    identity.append(name, detail);
    const state = document.createElement('span'); state.className = 'presence-state';
    state.textContent = value.login_metadata_valid ? 'Login-ready reference' : 'Needs approved local art';
    row.append(identity, state); return row;
  }));
}

function renderPresence(characters) {
  presentCount = characters.filter(character => character.connected).length;
  byId('presence-count').textContent = `${presentCount} present`;
  byId('character-presence').replaceChildren(...characters.map(character => {
    const row = document.createElement('article');
    row.className = `presence-row ${character.connected ? 'present' : character.assigned ? 'offline' : 'available'}`;
    const identity = document.createElement('div');
    const name = document.createElement('strong'); name.textContent = character.name;
    const detail = document.createElement('span'); detail.textContent = `${character.species} · ${character.class_name}`;
    identity.append(name, detail);
    const state = document.createElement('span'); state.className = 'presence-state';
    state.textContent = character.connected ? 'Present' : character.assigned ? 'Assigned · Offline' : 'Available';
    row.append(identity, state); return row;
  }));
  if (!journeyLive) byId('journey-status').textContent = presentCount
    ? journeyHasHistory
      ? `${presentCount} Wayfolio${presentCount === 1 ? ' is' : 's are'} present. Continue from the saved scene when ready.`
      : `${presentCount} Wayfolio${presentCount === 1 ? ' is' : 's are'} present. Start the new journey when ready.`
    : 'No players are present yet. Join the central game from at least one Wayfolio.';
  updateStartButton();
}

function showProposal(value) {
  proposal = value;
  byId('proposal-panel').hidden = !value;
  if (!value) return;
  byId('declaration').textContent = value.declaration;
  byId('intent').value = value.interpretation.intent;
  byId('review-skill').value = value.interpretation.skill;
  byId('review-dc').value = value.interpretation.dc;
  byId('requires-roll').checked = value.interpretation.requires_roll;
  byId('reason').value = value.interpretation.reason;
  byId('stakes').value = value.interpretation.stakes;
}

function showConsequence(value) {
  consequence = value;
  byId('consequence-panel').hidden = !value;
  if (!value) return;
  byId('consequence-declaration').textContent = value.declaration;
  byId('roll-summary').textContent = value.roll
    ? `${value.roll.skill}: d20 ${value.roll.die} + ${value.roll.modifier} = ${value.roll.total} vs DC ${value.roll.dc}`
    : 'The DM approved this action without a roll.';
  byId('adjudication-source').textContent = `Draft source: ${value.adjudication_source}`;
  byId('public-narration').value = value.public_narration;
  byId('private-information').value = value.private_information;
  byId('elapsed-minutes').value = value.delta.elapsed_minutes;
  byId('state-delta').textContent = JSON.stringify(value.delta, null, 2);
  byId('companion-preview').replaceChildren(...(value.companion_lines || []).map(line => {
    const item = document.createElement('article'); item.className = 'action';
    const speaker = document.createElement('strong'); speaker.textContent = line.speaker_id === 'soren' ? 'Soren' : 'Lupin';
    const text = document.createElement('p'); text.textContent = line.text; item.append(speaker, text); return item;
  }));
}

function renderLog(values) {
  byId('review-log').replaceChildren(...values.map(value => {
    const item = document.createElement('article');
    item.className = 'action';
    const title = document.createElement('strong');
    title.textContent = `${value.status} · ${value.author}`;
    const text = document.createElement('p');
    text.textContent = value.declaration;
    item.append(title, text);
    return item;
  }));
}

function ruling(action) {
  if (!proposal) return;
  socket.send(JSON.stringify({type:'dm_review_ruling', proposal_id:proposal.id, action,
    interpretation:{intent:byId('intent').value, skill:byId('review-skill').value,
      dc:Number(byId('review-dc').value), requires_roll:byId('requires-roll').checked,
      reason:byId('reason').value, stakes:byId('stakes').value}}));
}

byId('start-open-play').addEventListener('click', event => {
  if (socket.readyState !== WebSocket.OPEN || presentCount === 0) return;
  event.currentTarget.disabled = true;
  event.currentTarget.textContent = journeyHasHistory ? 'Continuing Journey…' : 'Starting Journey…';
  byId('journey-status').textContent = journeyHasHistory ? 'Restoring the saved scene…' : 'Preparing the opening scene…';
  socket.send(JSON.stringify({type:journeyHasHistory ? 'dm_journey_continue' : 'dm_journey_start'}));
});
byId('approve-ruling').addEventListener('click', () => ruling('approve'));
byId('resolve-no-roll').addEventListener('click', () => ruling('resolve_no_roll'));
byId('reject-ruling').addEventListener('click', () => ruling('clarify'));
byId('commit-consequence').addEventListener('click', () => {
  if (!consequence) return;
  socket.send(JSON.stringify({type:'dm_commit_consequence', consequence_id:consequence.id,
    consequence:{public_narration:byId('public-narration').value,
      private_information:byId('private-information').value,
      elapsed_minutes:Number(byId('elapsed-minutes').value)}}));
});
byId('undo-turn').addEventListener('click', () => socket.send(JSON.stringify({type:'dm_undo_open_play'})));
