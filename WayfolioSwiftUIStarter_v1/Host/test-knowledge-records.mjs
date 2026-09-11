import assert from 'node:assert/strict';
import {stableKnowledgeRecordID, upsertKnowledgeRecord} from './knowledge-records.mjs';

const id = stableKnowledgeRecordID('creature', 'unidentified-slime');
let result = upsertKnowledgeRecord([], {id:'unidentified-slime', kind:'creature', name:'Unidentified Slime',
  note:'Its surface holds suspended leaves.', provenance:'txn-1'}, '2026-09-09T00:00:00.000Z');
assert.equal(result.created, true);
result = upsertKnowledgeRecord(result.records, {id:'unidentified-slime', kind:'creature', name:'Unidentified Slime',
  note:'It responds to gentle vibration.', provenance:'txn-2'}, '2026-09-09T00:01:00.000Z');
assert.equal(result.created, false);
assert.equal(result.records.length, 1);
assert.deepEqual(result.record.notes, ['Its surface holds suspended leaves.', 'It responds to gentle vibration.']);
assert.deepEqual(result.record.provenance, ['txn-1', 'txn-2']);
assert.equal(stableKnowledgeRecordID('creature', 'unidentified-slime'), id);
console.log('Progressive discovery creates one stable record and enriches it without duplication.');
