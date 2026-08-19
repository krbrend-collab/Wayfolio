const role = document.body.dataset.role;
const socket = new WebSocket(`ws://${location.host}/session`);
const byId = id => document.getElementById(id);
let pendingRoll = null;
let latestPresentationState = null;

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
  panel.hidden = false;
  byId('roll-request').textContent = `${roll.playerName} chose “${roll.choice}” — ${roll.skill} check, DC ${roll.dc}, modifier +${roll.modifier}`;
}

socket.addEventListener('open', () => socket.send(JSON.stringify({type:'join', role, session_code:'HEMLOCK'})));
socket.addEventListener('message', event => {
  const message = JSON.parse(event.data);
  if (message.scene_title) byId('scene-title').textContent = message.scene_title;
  if (message.scene_text) byId('scene-text').textContent = message.scene_text;
  if (message.players) byId('players').textContent = message.players.length ? message.players.map(p => `${p.name}${p.connected ? ' • connected' : ''}`).join(' · ') : 'Waiting for Wayfolios…';
  if (message.last_choice && byId('choice')) byId('choice').textContent = `Renn chose: ${message.last_choice.choice}`;
  if (message.last_result && byId('result')) {
    const result = message.last_result;
    byId('result').textContent = `${result.player_name}: ${result.skill} ${result.total} vs DC ${result.dc} — ${result.succeeded ? 'success' : 'failure'}`;
    if (byId('roll-panel')) byId('roll-panel').hidden = true;
  }
  if (message.type === 'roll_requested') showRoll(message.roll);
  if (message.pending_roll) showRoll(message.pending_roll);
  if (message.type === 'action_event') renderAction(message);
  if (message.action_log && role === 'dm') message.action_log.slice().reverse().forEach(renderAction);
  if (message.presentation_state) latestPresentationState = message.presentation_state;
  if (message.type === 'presentation_event' && role === 'screen') window.wayfolioAudio?.handle(message.event);
});

if (byId('enable-audio')) {
  byId('enable-audio').addEventListener('click', async () => {
    await window.wayfolioAudio.enable();
    await window.wayfolioAudio.restore(latestPresentationState);
    byId('enable-audio').textContent = 'Audio enabled';
    byId('enable-audio').disabled = true;
  });
  document.querySelectorAll('[data-bus-volume]').forEach(input => {
    input.addEventListener('input', () => window.wayfolioAudio.setBusVolume(input.dataset.busVolume, input.value));
  });
}

function submitTableAction(visibility) {
  const input = byId('action-text');
  const text = input?.value.trim();
  if (!text) return;
  socket.send(JSON.stringify({type:'action_submit', player_id:'table', author:'At the table', text, visibility}));
  input.value = '';
  byId('action-status').textContent = visibility === 'private'
    ? 'Sent privately to the DM.' : 'Shared with the table.';
}

if (byId('action-public')) {
  byId('action-public').addEventListener('click', () => submitTableAction('public'));
  byId('action-private').addEventListener('click', () => submitTableAction('private'));
}

if (byId('digital-roll')) {
  byId('digital-roll').addEventListener('click', () => {
    if (pendingRoll) socket.send(JSON.stringify({type:'roll_submit', roll_id:pendingRoll.id, mode:'digital'}));
  });
  byId('physical-roll').addEventListener('click', () => {
    const die = Number(byId('physical-die').value);
    if (pendingRoll && Number.isInteger(die) && die >= 1 && die <= 20) {
      socket.send(JSON.stringify({type:'roll_submit', roll_id:pendingRoll.id, mode:'physical', die}));
    } else {
      byId('roll-error').textContent = 'Enter the face shown on the physical d20, from 1 to 20.';
    }
  });
}

if (role === 'dm') {
  const present = event => socket.send(JSON.stringify({type:'dm_presentation', event}));
  byId('start-encounter').addEventListener('click', () => socket.send(JSON.stringify({type:'dm_start_encounter'})));
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
    type:'dialogue', line_id:crypto.randomUUID(), speaker_id:byId('speaker-id').value || 'narrator',
    text:byId('dialogue-text').value, performance:byId('performance').value,
    priority:'normal', interrupt:'queue', caption:true,
  }));
  byId('stop-all-audio').addEventListener('click', () => present({type:'audio_control', action:'stop_all', fade_duration:0.25}));
}
