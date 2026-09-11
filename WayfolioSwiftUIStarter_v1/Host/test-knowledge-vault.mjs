import assert from 'node:assert/strict';
import {mkdtemp, readFile} from 'node:fs/promises';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {KnowledgeVault} from './knowledge-vault.mjs';

const seed = JSON.parse(await readFile(new URL('./content/hemlock-knowledge.json', import.meta.url), 'utf8'));
const directory = await mkdtemp(join(tmpdir(), 'wayfolio-vault-'));
const vault = new KnowledgeVault({path:join(directory, 'vault.json'), seed});
await vault.initialize();

const context = vault.buildContext({query:'Renn asks Soren about the blue motes', viewer:{role:'party'}, character_ids:['renn']});
assert(context.records.some(record => record.id === 'governance:player-sovereignty'));
assert(context.records.some(record => record.id === 'character:soren'));
assert(context.records.some(record => record.id === 'location:hemlock-bridge'));

const proposal = await vault.propose({kind:'relationship_canon', title:'A proposed memory', content:'Not canon until reviewed.', visibility:'party'});
assert.equal(vault.buildContext({query:'proposed memory', viewer:{role:'party'}}).records.some(record => record.id === proposal.id), false);
await vault.review({proposal_id:proposal.id, action:'approve'});
assert.equal(vault.buildContext({query:'proposed memory', viewer:{role:'party'}}).records.some(record => record.id === proposal.id), true);

await vault.recordCommittedTurn({transaction_id:'tx-1', turn_id:'turn-1', declaration:'I listen beneath the bridge.',
  public_narration:'The water carries a distant chime.', companion_lines:[], campaign_time_after:{period:'evening',elapsed_minutes:2}, resulting_state_head:'head-2'});
assert.equal(vault.buildContext({query:'distant chime', viewer:{role:'party'}}).records.some(record => record.id === 'turn:tx-1'), true);
console.log('Knowledge Vault tests passed.');
