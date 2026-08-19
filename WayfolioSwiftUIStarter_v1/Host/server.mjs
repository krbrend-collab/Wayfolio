import http from 'node:http';
import {mkdir, readFile, rename, writeFile} from 'node:fs/promises';
import {extname, join, resolve, sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {WebSocketServer, WebSocket} from 'ws';

const root = join(fileURLToPath(new URL('.', import.meta.url)), 'public');
const port = Number(process.env.PORT || 8787);
const dataDirectory = join(fileURLToPath(new URL('.', import.meta.url)), 'data');
const statePath = join(dataDirectory, 'campaign-state.json');
const contentDirectory = join(fileURLToPath(new URL('.', import.meta.url)), 'content');
const starterRoot = fileURLToPath(new URL('..', import.meta.url));
const audioRoot = join(starterRoot, 'Wayfolio', 'Resources', 'Audio');
const audioSpecRoot = join(starterRoot, 'Specifications', 'Audio');
const audioCatalog = JSON.parse(await readFile(join(audioSpecRoot, 'AudioCueCatalog.json'), 'utf8'));
const creatureProfiles = JSON.parse(await readFile(join(audioSpecRoot, 'CreatureAudioProfiles.json'), 'utf8'));
const characterVoiceProfiles = JSON.parse(await readFile(join(audioSpecRoot, 'CharacterVoiceProfiles.json'), 'utf8'));
const locationAmbienceProfiles = JSON.parse(await readFile(join(audioSpecRoot, 'LocationAmbienceProfiles.json'), 'utf8'));
const cueIDs = new Set(audioCatalog.cues.map(cue => cue.id));
const renn = JSON.parse(await readFile(join(contentDirectory, 'renn.json'), 'utf8'));
const bridgeEncounter = JSON.parse(await readFile(join(contentDirectory, 'hemlock-bridge.json'), 'utf8'));
const session = {
  code: 'HEMLOCK',
  sceneTitle: 'The Lantern Road',
  sceneText: 'Evening settles over Hemlock Village. Blue motes gather beneath the old bridge.',
  players: new Map(),
  lastChoice: null,
  lastResult: null,
  prompt: null,
  pendingRoll: null,
  activeEncounter: null,
  characterState: {inventory:[...renn.inventory], discoveries:[], journal:[]},
  actionLog: [],
  presentationSequence: 0,
  presentationState: {ambience:null, music:null},
};

try {
  const saved = JSON.parse(await readFile(statePath, 'utf8'));
  session.sceneTitle = saved.sceneTitle || session.sceneTitle;
  session.sceneText = saved.sceneText || session.sceneText;
  session.lastChoice = saved.lastChoice || null;
  session.lastResult = saved.lastResult || null;
  session.activeEncounter = saved.activeEncounter || null;
  session.characterState = saved.characterState || session.characterState;
  session.actionLog = saved.actionLog || [];
  session.presentationSequence = saved.presentationSequence || 0;
  session.presentationState = saved.presentationState || session.presentationState;
} catch {}

async function saveSession() {
  await mkdir(dataDirectory, {recursive:true});
  const temporary = `${statePath}.${crypto.randomUUID()}.tmp`;
  await writeFile(temporary, JSON.stringify({
    code:session.code,
    sceneTitle:session.sceneTitle,
    sceneText:session.sceneText,
    lastChoice:session.lastChoice,
    lastResult:session.lastResult,
    activeEncounter:session.activeEncounter,
    characterState:session.characterState,
    actionLog:session.actionLog,
    presentationSequence:session.presentationSequence,
    presentationState:session.presentationState,
  }, null, 2));
  await rename(temporary, statePath);
}

const types = {'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.json':'application/json','.wav':'audio/wav','.m4a':'audio/mp4','.mp3':'audio/mpeg'};
const server = http.createServer(async (request, response) => {
  const pathname = new URL(request.url, `http://${request.headers.host}`).pathname;
  if (['/audio-catalog.json', '/creature-audio-profiles.json', '/character-voice-profiles.json', '/location-ambience-profiles.json'].includes(pathname)) {
    const value = pathname === '/audio-catalog.json' ? audioCatalog
      : pathname === '/creature-audio-profiles.json' ? creatureProfiles
      : pathname === '/character-voice-profiles.json' ? characterVoiceProfiles : locationAmbienceProfiles;
    response.writeHead(200, {'content-type':'application/json', 'cache-control':'no-store'});
    return response.end(JSON.stringify(value));
  }
  if (pathname.startsWith('/Audio/')) {
    const candidate = resolve(audioRoot, pathname.slice('/Audio/'.length));
    if (!candidate.startsWith(`${resolve(audioRoot)}${sep}`)) return response.writeHead(403).end('Forbidden');
    try {
      const data = await readFile(candidate);
      response.writeHead(200, {'content-type':types[extname(candidate)] || 'application/octet-stream', 'cache-control':'public, max-age=3600'});
      return response.end(data);
    } catch {
      return response.writeHead(404).end('Audio cue not found');
    }
  }
  const relative = pathname === '/' ? 'index.html' : pathname === '/dm' ? 'dm.html' : pathname.slice(1);
  try {
    const data = await readFile(join(root, relative));
    response.writeHead(200, {'content-type': types[extname(relative)] || 'application/octet-stream'});
    response.end(data);
  } catch {
    response.writeHead(404).end('Not found');
  }
});

const sockets = new WebSocketServer({server, path: '/session'});

function send(socket, message) {
  if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message));
}

function broadcast(message, predicate = () => true) {
  for (const client of sockets.clients) if (predicate(client)) send(client, message);
}

function snapshot(role = 'screen', playerID = null) {
  const value = {
    type: 'session_snapshot',
    session_code: session.code,
    scene_title: session.sceneTitle,
    scene_text: session.sceneText,
    players: [...session.players.values()],
    last_choice: session.lastChoice,
    last_result: session.lastResult,
    pending_roll: session.pendingRoll,
  };
  if (role === 'screen' || role === 'dm') value.presentation_state = session.presentationState;
  if (role === 'dm' || (role === 'wayfolio' && playerID === renn.id)) {
    value.character = renn;
    value.character_state = session.characterState;
    value.action_log = role === 'dm' ? session.actionLog : session.actionLog.filter(action => action.player_id === playerID);
  }
  return value;
}

function validPresentationEvent(event) {
  if (!event || typeof event !== 'object') return false;
  if (['ui_sound', 'sound_effect'].includes(event.type)) return cueIDs.has(event.cue);
  if (event.type === 'creature_sound') {
    return ['creature_id', 'creature_type', 'behavior'].every(key => typeof event[key] === 'string' && event[key]);
  }
  if (['ambience', 'music'].includes(event.type)) {
    return ['play', 'stop'].includes(event.action) && (event.action === 'stop' || cueIDs.has(event.cue));
  }
  if (event.type === 'ambience_scene') {
    return ['play', 'stop'].includes(event.action)
      && (event.action === 'stop' || Boolean(locationAmbienceProfiles.profiles[event.profile]));
  }
  if (event.type === 'dialogue') return typeof event.text === 'string' && event.text.trim().length > 0;
  return event.type === 'audio_control' && ['stop_all', 'pause', 'resume'].includes(event.action);
}

function emitPresentation(event) {
  if (!validPresentationEvent(event)) return false;
  session.presentationSequence += 1;
  if (event.type === 'ambience' || event.type === 'ambience_scene') session.presentationState.ambience = event.action === 'play' ? event : null;
  if (event.type === 'music') session.presentationState.music = event.action === 'play' ? event : null;
  if (event.type === 'audio_control' && event.action === 'stop_all') {
    session.presentationState = {ambience:null, music:null};
  }
  broadcast({
    type:'presentation_event', protocol:'wayfolio.presentation.v1',
    event_id:crypto.randomUUID(), sequence:session.presentationSequence,
    session_code:session.code, scene_id:session.activeEncounter?.id || 'hemlock-open',
    audience:{kind:'shared'}, event,
  }, client => client.meta.role === 'screen' || client.meta.role === 'dm');
  return true;
}

function broadcastSnapshots() {
  for (const client of sockets.clients) {
    send(client, snapshot(client.meta.role, client.meta.playerID));
  }
}

function resolveRoll(pending, die, mode) {
  const total = die + pending.modifier;
  const succeeded = total >= pending.dc;
  session.lastResult = {
    player_id:pending.playerID, player_name:pending.playerName, choice:pending.choice,
    skill:pending.skill, die, modifier:pending.modifier, total, dc:pending.dc, succeeded, mode,
    detail:`d20 ${die} + ${pending.modifier} = ${total} against DC ${pending.dc}`,
    at:new Date().toISOString(),
  };
  session.pendingRoll = null;
  const encounter = pending.encounterID === bridgeEncounter.id ? bridgeEncounter : null;
  if (encounter) {
    const outcome = succeeded ? encounter.success : encounter.failure;
    session.sceneTitle = outcome.shared_title;
    session.sceneText = outcome.shared_text;
    session.activeEncounter = {...session.activeEncounter, status:'resolved', succeeded};
    if (outcome.discovery && !session.characterState.discoveries.includes(outcome.discovery)) {
      session.characterState.discoveries.push(outcome.discovery);
    }
    if (outcome.journal && !session.characterState.journal.includes(outcome.journal)) {
      session.characterState.journal.push(outcome.journal);
    }
    broadcast({type:'scene_update', scene_title:session.sceneTitle, scene_text:session.sceneText},
      client => client.meta.role === 'screen' || client.meta.role === 'dm');
    pending.privateText = outcome.private_text;
  }
  broadcast({
    type:'private_result', title:succeeded ? 'Check succeeded' : 'Check failed',
    detail:`${pending.skill}: ${session.lastResult.detail}${pending.privateText ? `\n\n${pending.privateText}` : ''}`,
    succeeded,
  }, client => client.meta.playerID === pending.playerID);
  broadcastSnapshots();
  void saveSession();
}

sockets.on('connection', socket => {
  socket.meta = {role: 'unknown', playerID: null};
  socket.on('message', raw => {
    let message;
    try { message = JSON.parse(raw); } catch { return send(socket, {type:'error', message:'Invalid message.'}); }

    if (message.type === 'join') {
      if (String(message.session_code).toUpperCase() !== session.code) {
        return send(socket, {type:'error', message:'That session code is not active.'});
      }
      socket.meta = {role: message.role, playerID: message.player_id || null};
      if (message.role === 'wayfolio') {
        session.players.set(message.player_id, {id:message.player_id, name:message.player_name, connected:true});
      }
      send(socket, {type:'joined', session_code:session.code});
      send(socket, snapshot(socket.meta.role, socket.meta.playerID));
      broadcastSnapshots();
      return;
    }

    if (message.type === 'dm_scene' && socket.meta.role === 'dm') {
      session.sceneTitle = message.scene_title || session.sceneTitle;
      session.sceneText = message.scene_text || session.sceneText;
      broadcast({type:'scene_update', scene_title:session.sceneTitle, scene_text:session.sceneText});
      void saveSession();
    }

    if (message.type === 'dm_presentation' && socket.meta.role === 'dm') {
      if (!emitPresentation(message.event)) {
        return send(socket, {type:'error', message:'Invalid presentation event or unknown cue.'});
      }
      void saveSession();
    }

    if (message.type === 'dm_prompt' && socket.meta.role === 'dm') {
      session.prompt = {
        id:crypto.randomUUID(), playerID:message.player_id, title:message.title,
        message:message.message, choices:message.choices, skill:message.skill || 'Insight',
        dc:Number(message.dc || 12), modifier:Number(message.modifier || 3),
      };
      broadcast({
        type:'private_prompt', prompt_id:session.prompt.id, title:session.prompt.title,
        message:session.prompt.message, choices:session.prompt.choices,
      }, client => client.meta.playerID === message.player_id);
    }

    if (message.type === 'dm_start_encounter' && socket.meta.role === 'dm') {
      session.activeEncounter = {id:bridgeEncounter.id, status:'in_progress'};
      session.sceneTitle = bridgeEncounter.title;
      session.sceneText = bridgeEncounter.opening;
      session.prompt = {
        id:crypto.randomUUID(), playerID:renn.id, title:bridgeEncounter.prompt_title,
        message:bridgeEncounter.prompt_message, choices:bridgeEncounter.choices.map(choice => choice.label),
        encounterID:bridgeEncounter.id,
      };
      broadcast({type:'scene_update', scene_title:session.sceneTitle, scene_text:session.sceneText},
        client => client.meta.role === 'screen' || client.meta.role === 'dm');
      broadcast({type:'private_prompt', prompt_id:session.prompt.id, title:session.prompt.title,
        message:session.prompt.message, choices:session.prompt.choices},
        client => client.meta.playerID === renn.id);
      emitPresentation({type:'ambience', action:'play', cue:'hemlock_forest', volume:0.5, fade_duration:1.5});
      emitPresentation({type:'music', action:'play', cue:'forest_exploration', volume:0.42, intensity:0.25, fade_duration:2});
      emitPresentation({type:'dialogue', line_id:'bridge-opening', speaker_id:'narrator',
        text:bridgeEncounter.opening, performance:'warm, measured, quietly mysterious',
        priority:'normal', interrupt:'queue', caption:true});
      void saveSession();
    }

    if (message.type === 'player_choice' && socket.meta.role === 'wayfolio') {
      session.lastChoice = {player_id:socket.meta.playerID, choice:message.choice, at:new Date().toISOString()};
      const prompt = session.prompt?.id === message.prompt_id
        ? session.prompt
        : {skill:'Insight', dc:12, modifier:3};
      const encounterChoice = prompt.encounterID === bridgeEncounter.id
        ? bridgeEncounter.choices.find(choice => choice.label === message.choice)
        : null;
      const skill = encounterChoice?.skill || prompt.skill || 'Insight';
      const modifier = renn.skills[skill] ?? Number(prompt.modifier || 0);
      const dc = encounterChoice?.dc || Number(prompt.dc || 12);
      session.pendingRoll = {
        id:crypto.randomUUID(), playerID:socket.meta.playerID, playerName:'Renn',
        choice:message.choice, skill, dc, modifier, encounterID:prompt.encounterID || null,
      };
      session.prompt = null;
      send(socket, {type:'choice_received', message:'Choose physical or digital dice on the shared screen.'});
      broadcast({type:'roll_requested', roll:session.pendingRoll},
        client => client.meta.role === 'dm' || client.meta.role === 'screen');
    }

    if (message.type === 'roll_submit' && ['dm', 'screen'].includes(socket.meta.role)) {
      const pending = session.pendingRoll;
      if (!pending || message.roll_id !== pending.id) {
        return send(socket, {type:'error', message:'That roll is no longer pending.'});
      }
      const mode = message.mode === 'physical' ? 'physical' : 'digital';
      const die = mode === 'digital' ? Math.floor(Math.random() * 20) + 1 : Number(message.die);
      if (!Number.isInteger(die) || die < 1 || die > 20) {
        return send(socket, {type:'error', message:'A physical d20 result must be from 1 through 20.'});
      }
      resolveRoll(pending, die, mode);
    }

    if (message.type === 'action_submit' && ['wayfolio', 'screen'].includes(socket.meta.role)) {
      const text = String(message.text || '').trim().slice(0, 1000);
      if (!text) return send(socket, {type:'error', message:'An action cannot be empty.'});
      const visibility = message.visibility === 'public' ? 'public' : 'private';
      const action = {
        id:crypto.randomUUID(), player_id:message.player_id || socket.meta.playerID || 'table',
        author:String(message.author || (socket.meta.role === 'screen' ? 'At the table' : 'Player')),
        text, visibility, at:new Date().toISOString(),
      };
      session.actionLog.unshift(action);
      session.actionLog = session.actionLog.slice(0, 100);
      const event = {type:'action_event', action_id:action.id, player_id:action.player_id,
        author:action.author, text:action.text, visibility:action.visibility};
      broadcast(event, client => client.meta.role === 'dm' ||
        (visibility === 'public' && client.meta.role === 'screen') ||
        (client.meta.role === 'wayfolio' && client.meta.playerID === action.player_id));
      send(socket, {...event, type:'action_ack'});
      void saveSession();
    }
  });

  socket.on('close', () => {
    if (socket.meta.playerID && session.players.has(socket.meta.playerID)) {
      session.players.get(socket.meta.playerID).connected = false;
      broadcastSnapshots();
    }
  });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Wayfolio host: http://localhost:${port}`);
  console.log(`DM controls:  http://localhost:${port}/dm`);
});
