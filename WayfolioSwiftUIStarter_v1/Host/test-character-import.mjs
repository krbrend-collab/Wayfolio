import {readFile} from 'node:fs/promises';
import {WebSocket} from 'ws';

const port = Number(process.env.PORT || 8787);
const statePath = process.env.WAYFOLIO_SESSION_STATE_PATH;
if (!statePath) throw new Error('WAYFOLIO_SESSION_STATE_PATH is required for this test.');

const characterName = `Archive Keeper ${Date.now()}`;
const packageBody = {
  format:'wayfolio-character', version:'1.1',
  identity:{name:characterName, species:'Human', class:'Wizard', level:3, background:'Archivist'},
  statistics:{maximum_hp:18, current_hp:18, armor_class:12, initiative:2,
    abilities:{strength:8, dexterity:14, constitution:12, intelligence:17, wisdom:13, charisma:10}},
  background:{history:'A complete history that must survive normalization.', private_memory:'A player-held memory.'},
  privacy:{public:{manner:'Careful'}, player_only:{hope:'Restore the archive'}, dm_only:{secret:'The map is counterfeit'}},
  additional_material:[{title:'Unusual oath', content:'Never erase a witness.', visibility:'player_only'}],
  custom_cosmology:{moons:['Aster','Vale'], interpretation:'Personal belief, not an authoritative rule.'},
  source_documents:[{filename:'player-only-notes.txt', mime_type:'text/plain', visibility:'player_only',
    data_base64:Buffer.from('Original notes remain available.').toString('base64')}],
};

const response = await fetch(`http://localhost:${port}/api/characters/import`, {
  method:'POST', headers:{'content-type':'application/json'}, body:JSON.stringify(packageBody),
});
const result = await response.json();
if (!response.ok || !result.character?.id) throw new Error(result.error || 'Character import failed.');

const state = JSON.parse(await readFile(statePath, 'utf8'));
const stored = state.customCharacters.find(character => character.id === result.character.id);
if (!stored) throw new Error('The imported character was not persisted.');
if (stored.character_profile?.preserved_source?.custom_cosmology?.moons?.length !== 2) {
  throw new Error('An unrecognized character section was discarded.');
}
if (stored.character_profile?.background?.history !== packageBody.background.history) {
  throw new Error('Background development was not preserved.');
}
if (stored.character_profile?.player_only?.hope !== packageBody.privacy.player_only.hope ||
    stored.character_profile?.dm_only?.secret !== packageBody.privacy.dm_only.secret) {
  throw new Error('Character privacy sections were not preserved.');
}
if (stored.character_profile?.source_documents?.[0]?.visibility !== 'player_only') {
  throw new Error('Supporting document privacy was not preserved.');
}

const socket = new WebSocket(`ws://localhost:${port}/session`);
await new Promise((resolve, reject) => { socket.once('open', resolve); socket.once('error', reject); });
socket.send(JSON.stringify({type:'join', role:'wayfolio', session_code:'HEMLOCK', player_id:stored.id,
  player_name:stored.name, character_id:stored.id, device_id:'character-import-privacy-test'}));
const messages = [];
await new Promise((resolve, reject) => {
  const timeout = setTimeout(() => reject(new Error('Timed out waiting for the imported character snapshot.')), 3000);
  socket.on('message', raw => {
    const value = JSON.parse(raw);
    messages.push(value);
    if (value.type === 'session_snapshot') { clearTimeout(timeout); resolve(); }
  });
});
socket.close();
const snapshot = messages.find(value => value.type === 'session_snapshot');
if (snapshot.character?.character_profile || JSON.stringify(snapshot).includes(packageBody.privacy.dm_only.secret)) {
  throw new Error('Private imported material leaked into the playable Wayfolio snapshot.');
}

console.log('Complete character package import passed.');
