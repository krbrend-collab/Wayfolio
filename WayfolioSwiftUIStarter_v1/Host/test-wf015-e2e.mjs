import assert from 'node:assert/strict';
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

function connect(port, role, extra = {}) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(`ws://127.0.0.1:${port}/session`);
    const messages = []; const waiters = [];
    socket.on('message', raw => {
      const message = JSON.parse(raw);
      const index = waiters.findIndex(waiter => waiter.predicate(message));
      if (index >= 0) waiters.splice(index, 1)[0].resolve(message); else messages.push(message);
    });
    const next = (predicate, timeout = 12_000) => {
      const index = messages.findIndex(predicate);
      if (index >= 0) return Promise.resolve(messages.splice(index, 1)[0]);
      return new Promise((resolveNext, rejectNext) => {
        const waiter = {predicate, resolve:resolveNext}; waiters.push(waiter);
        const timer = setTimeout(() => {
          const position = waiters.indexOf(waiter); if (position >= 0) waiters.splice(position, 1);
          rejectNext(new Error(`Timed out waiting for ${role} event. Recent: ${messages.slice(-8).map(item =>
            `${item.type}${item.storyteller_transport?.state ? `:${item.storyteller_transport.state}` : ''}${item.transaction?.declaration ? `:${item.transaction.declaration}` : ''}`).join(', ')}`));
        }, timeout); timer.unref?.();
      });
    };
    socket.once('error', reject);
    socket.once('open', async () => {
      socket.send(JSON.stringify({type:'join', role, session_code:'HEMLOCK', ...extra}));
      await next(message => message.type === 'joined'); resolve({socket,next,messages});
    });
  });
}

async function waitForHost(child) {
  return new Promise((resolve, reject) => {
    let output = '';
    const timer = setTimeout(() => reject(new Error(`Host did not start. ${output}`)), 15_000);
    child.stdout.on('data', chunk => {
      output += chunk; if (output.includes('Wayfolio host:')) { clearTimeout(timer); resolve(); }
    });
    child.stderr.on('data', chunk => { output += chunk; });
    child.once('exit', code => { clearTimeout(timer); reject(new Error(`Host exited ${code}. ${output}`)); });
  });
}

async function runScenario({budgetUSD, complex = false}) {
  const temporary = await mkdtemp(join(tmpdir(), 'wayfolio-wf015-'));
  const campaign = join(temporary, 'campaign');
  await cp(new URL('../Campaigns/HemlockDevelopment/', import.meta.url), campaign, {recursive:true});
  let responseCalls = 0;
  const provider = createServer(async (request, response) => {
    if (request.url === '/v1/models') {
      response.writeHead(200, {'content-type':'application/json'}).end(JSON.stringify({data:[]})); return;
    }
    if (request.url !== '/v1/responses') { response.writeHead(404).end(); return; }
    responseCalls += 1;
    const chunks = []; for await (const chunk of request) chunks.push(chunk);
    const payload = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    const input = JSON.parse(payload.input); const declaration = input.payload?.exact_declaration || '';
    const result = {
      public_narration:`The world responds openly to Renn's declared approach: ${declaration}`,
      private_information:'Renn notices a faint rhythmic change that only his careful attention reveals.',
      companion_lines:[
        {speaker_id:'unbound-rowan-reference',text:'Tell me what happened, and I will help where I can.',performance:'calm, attentive'}
      ],
      elapsed_minutes:3,
      new_known_clue:'The injured slime responds more calmly when movement around the trapped metal is slow and predictable.',
      entity_disposition:{id:'injured-slime',disposition:'cautiously_receptive'}
    };
    const usage = {input_tokens:650,input_tokens_details:{cached_tokens:300,cache_write_tokens:0},output_tokens:180,total_tokens:830};
    response.writeHead(200, {'content-type':'application/json','x-request-id':`wf015-${responseCalls}`})
      .end(JSON.stringify({id:`resp-${responseCalls}`,output_text:JSON.stringify(result),usage}));
  });
  const providerPort = await listen(provider);
  const portProbe = createServer(); const port = await listen(portProbe); await new Promise(resolve => portProbe.close(resolve));
  const child = spawn(process.execPath, ['server.mjs'], {cwd:new URL('.', import.meta.url), env:{...process.env,
    PORT:String(port), WAYFOLIO_DATA_DIRECTORY:join(temporary,'data'), WAYFOLIO_CAMPAIGN_PATH:campaign,
    WAYFOLIO_OPENAI_BASE_URL:`http://127.0.0.1:${providerPort}/v1`, OPENAI_API_KEY:'sk-wf015-test-12345678901234567890',
    WAYFOLIO_AI_SESSION_BUDGET_USD:String(budgetUSD)}, stdio:['ignore','pipe','pipe']});
  child.stderr.on('data', chunk => process.stderr.write(`[wf015 host] ${chunk}`));
  try {
    await waitForHost(child);
    const selected = await fetch(`http://127.0.0.1:${port}/api/launcher-library`, {method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({journey_id:'renn-intro-tutorial'})});
    assert.equal(selected.ok, true, await selected.text());
    const dm = await connect(port,'dm'); const screen = await connect(port,'screen');
    const player = await connect(port,'wayfolio',{player_id:'renn',player_name:'Renn Hazel',character_id:'renn',device_id:`wf015-${complex?'cap':'normal'}`});
    const initial = await dm.next(message => message.type === 'session_snapshot' && message.active_journey_id === 'renn-intro-tutorial');
    assert.deepEqual(initial.world_state.party.filter(member => member.present).map(member => member.id), ['renn']);
    assert.equal(initial.world_state.active_entities.find(entity => entity.id === 'injured-slime').encounter.combat_required, false);
    dm.socket.send(JSON.stringify({type:'dm_journey_continue'}));
    await dm.next(message => message.type === 'journey_continued');

    const declaration = complex ? 'I race Rowan to the service door.' : 'I ask Rowan for help with the injured slime.';
    const actionID = crypto.randomUUID();
    player.socket.send(JSON.stringify({type:'action_submit',client_action_id:actionID,player_id:'renn',author:'Renn',text:declaration,visibility:'public'}));
    await player.next(message => message.type === 'action_ack' && message.client_action_id === actionID);
    const progress = await dm.next(message => (message.type === 'turn_committed' && message.transaction.declaration === declaration)
      || (message.type === 'roll_requested' && message.roll?.choice === declaration));
    if (progress.type === 'roll_requested') {
      screen.socket.send(JSON.stringify({type:'roll_submit',roll_id:progress.roll.id,mode:complex?'digital':'physical',
        ...(complex?{}:{die:16}),client_roll_submission_id:crypto.randomUUID()}));
    }
    const committed = progress.type === 'turn_committed' ? progress
      : await dm.next(message => message.type === 'turn_committed' && message.transaction.declaration === declaration);
    assert.equal(committed.transaction.status,'COMMITTED');
    const snapshot = complex
      ? await player.next(message => message.type === 'session_snapshot' && message.character_state)
      : await player.next(message => message.type === 'session_snapshot' && message.character_state?.discoveries?.some(value => value.includes('slow and predictable')));
    assert.equal('storyteller_transport' in snapshot,false,'A personal Wayfolio must not receive provider or billing state.');
    if (complex) {
      const hostStatus = await dm.next(message => message.type === 'storyteller_transport_state'
        && message.storyteller_transport?.state === 'BUDGET_PAUSED');
      assert.equal(hostStatus.storyteller_transport.state,'BUDGET_PAUSED');
      const sharedStatus = await screen.next(message => message.type === 'storyteller_transport_state'
        && message.storyteller_transport?.state === 'BUDGET_PAUSED');
      assert.equal('low_cost_mode' in sharedStatus.storyteller_transport,false,'Shared status must not expose cost details.');
      assert.equal(responseCalls,0,'Preflight-blocked intent must pass once to Local Play without reaching the provider.');
    } else {
      const event = await screen.next(message => message.type === 'presentation_event'
        && message.event?.type === 'dialogue' && message.event?.speaker_id === 'unbound-rowan-reference');
      assert.equal(event.event.speaker_name,'Rowan');
      assert.equal(event.event.voice_profile_id,'unknown_voice');
      assert.equal(responseCalls,1);
    }
    for (const connection of [dm,screen,player]) connection.socket.close();
  } finally {
    if (child.exitCode === null) {
      child.kill('SIGTERM');
      await new Promise(resolve => child.once('exit', resolve));
    }
    await new Promise(resolve => provider.close(resolve));
    await rm(temporary,{recursive:true,force:true});
  }
}

await runScenario({budgetUSD:1,complex:false});
await runScenario({budgetUSD:0.000001,complex:true});
console.log('WF-015 normal live Storyteller and constrained Local Play host validations passed.');
