import {cp, mkdtemp, rm} from 'node:fs/promises';
import {createServer} from 'node:http';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {WebSocket} from 'ws';

function listen(server) {
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => resolve(server.address().port));
  });
}

class Inbox {
  constructor(socket) {
    this.messages = []; this.waiters = [];
    socket.on('message', raw => {
      const message = JSON.parse(raw);
      const index = this.waiters.findIndex(waiter => waiter.predicate(message));
      if (index >= 0) this.waiters.splice(index, 1)[0].resolve(message); else this.messages.push(message);
    });
  }
  next(predicate, timeout = 10_000) {
    const index = this.messages.findIndex(predicate);
    if (index >= 0) return Promise.resolve(this.messages.splice(index, 1)[0]);
    return new Promise((resolve, reject) => {
      const waiter = {predicate, resolve}; this.waiters.push(waiter);
      const timer = setTimeout(() => {
        const position = this.waiters.indexOf(waiter); if (position >= 0) this.waiters.splice(position, 1);
        reject(new Error(`Timed out waiting for encounter privacy state. Recent: ${this.messages.slice(-8).map(item => item.type).join(', ')}`));
      }, timeout); timer.unref?.();
    });
  }
}

async function joinRole(port, role, playerID = null) {
  const socket = new WebSocket(`ws://127.0.0.1:${port}/session`); const inbox = new Inbox(socket);
  await new Promise((resolve, reject) => { socket.once('open', resolve); socket.once('error', reject); });
  socket.send(JSON.stringify({type:'join',role,session_code:'HEMLOCK',...(playerID ? {
    player_id:playerID,player_name:'Renn',character_id:playerID,device_id:'encounter-privacy-test-device'} : {})}));
  await inbox.next(message => message.type === 'joined'); return {socket,inbox};
}

const temporary = await mkdtemp(join(tmpdir(),'wayfolio-encounter-privacy-'));
const campaign = join(temporary,'campaign');
await cp(new URL('../Campaigns/HemlockDevelopment/',import.meta.url),campaign,{recursive:true});
const probe = createServer(); const port = await listen(probe); await new Promise(resolve => probe.close(resolve));
const child = spawn(process.execPath,['server.mjs'],{cwd:new URL('.',import.meta.url),env:{...process.env,PORT:String(port),
  WAYFOLIO_DATA_DIRECTORY:join(temporary,'data'),WAYFOLIO_CAMPAIGN_PATH:campaign},stdio:['ignore','pipe','pipe']});
try {
  await new Promise((resolve,reject) => {
    let output=''; const timer=setTimeout(()=>reject(new Error(`Host did not start. ${output}`)),15_000);
    child.stdout.on('data',chunk=>{output+=chunk;if(output.includes('Wayfolio host:')){clearTimeout(timer);resolve();}});
    child.stderr.on('data',chunk=>{output+=chunk;}); child.once('exit',code=>reject(new Error(`Host exited ${code}. ${output}`)));
  });
  const dm=await joinRole(port,'dm'); const screen=await joinRole(port,'screen'); const player=await joinRole(port,'wayfolio','renn');
  dm.socket.send(JSON.stringify({type:'dm_start_monster_encounter'}));
  const states=await Promise.all([dm.inbox,screen.inbox,player.inbox].map(inbox=>inbox.next(message=>
    message.type==='session_snapshot'&&message.active_encounter?.combatants?.length)));
  const monsters=states.map(state=>state.active_encounter.combatants.find(value=>value.kind==='monster'));
  if(!monsters[0]||monsters[0].hp<1||monsters[0].hp>18||monsters[0].maximum_hp!==18) throw new Error('The private DM view lost authoritative monster health.');
  for(const monster of monsters.slice(1)) {
    if(!monster||monster.hp_visibility!==false||monster.hp!==0||monster.maximum_hp!==1) throw new Error('Exact monster health leaked outside the private DM view.');
    if(!monster.public_status) throw new Error('The player-safe encounter omitted its qualitative status.');
  }
  for(const connection of [dm,screen,player]) connection.socket.close();
  console.log('Encounter privacy projection passed on an isolated host.');
} finally {
  if (child.exitCode === null) {
    child.kill('SIGTERM');
    await new Promise(resolve => child.once('exit',resolve));
  }
  await rm(temporary,{recursive:true,force:true});
}
