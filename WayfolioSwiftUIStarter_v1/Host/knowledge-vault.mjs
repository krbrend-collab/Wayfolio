import crypto from 'node:crypto';
import {mkdir, readFile, rename, writeFile} from 'node:fs/promises';
import {dirname} from 'node:path';

const allowedVisibility = new Set(['public', 'party', 'player_private', 'host_only']);
const allowedStatus = new Set(['approved', 'proposed', 'superseded']);

function terms(value) {
  return new Set(String(value || '').toLowerCase().match(/[a-z0-9'-]{3,}/g) || []);
}

function visible(record, viewer) {
  if (record.status !== 'approved') return false;
  if (record.visibility === 'host_only') return viewer.role === 'host';
  if (record.visibility === 'player_private') {
    return viewer.role === 'host' || record.recipient_ids?.includes(viewer.player_id);
  }
  return true;
}

function normalizeRecord(value, fallback = {}) {
  const record = {...fallback, ...value};
  if (!record.id || !record.kind || !record.title || record.content === undefined) {
    throw new Error('Knowledge records require id, kind, title, and content.');
  }
  record.visibility = allowedVisibility.has(record.visibility) ? record.visibility : 'party';
  record.status = allowedStatus.has(record.status) ? record.status : 'proposed';
  record.recipient_ids = Array.isArray(record.recipient_ids) ? record.recipient_ids.map(String) : [];
  record.tags = Array.isArray(record.tags) ? record.tags.map(String) : [];
  record.provenance ||= {source:'unknown', authority:'unreviewed'};
  record.updated_at ||= new Date().toISOString();
  return record;
}

export class KnowledgeVault {
  constructor({path, seed}) {
    this.path = path;
    this.seed = seed;
    this.value = null;
  }

  async initialize() {
    try { this.value = JSON.parse(await readFile(this.path, 'utf8')); }
    catch { this.value = structuredClone(this.seed); await this.save(); }
    this.value.schema_version ||= 1;
    this.value.records = (this.value.records || []).map(record => normalizeRecord(record));
    this.value.proposals ||= [];
    return this.summary();
  }

  summary() {
    return {schema_version:this.value.schema_version, campaign_id:this.value.campaign_id,
      approved_records:this.value.records.filter(record => record.status === 'approved').length,
      pending_proposals:this.value.proposals.filter(record => record.status === 'proposed').length,
      updated_at:this.value.updated_at};
  }

  async save() {
    await mkdir(dirname(this.path), {recursive:true});
    this.value.updated_at = new Date().toISOString();
    const temporary = `${this.path}.${crypto.randomUUID()}.tmp`;
    await writeFile(temporary, JSON.stringify(this.value, null, 2));
    await rename(temporary, this.path);
  }

  buildContext({query, viewer = {role:'party'}, character_ids = [], limit = 24}) {
    const queryTerms = terms(`${query} ${character_ids.join(' ')}`);
    const ranked = this.value.records.filter(record => visible(record, viewer)).map(record => {
      const haystack = terms(`${record.id} ${record.kind} ${record.title} ${record.tags?.join(' ')} ${JSON.stringify(record.content)}`);
      let score = record.pinned ? 100 : 0;
      for (const term of queryTerms) if (haystack.has(term)) score += 5;
      if (record.kind === 'governance') score += 40;
      if (character_ids.some(id => record.subject_ids?.includes(id))) score += 30;
      return {record, score};
    }).filter(item => item.score > 0 || queryTerms.size === 0)
      .sort((a, b) => b.score - a.score || a.record.id.localeCompare(b.record.id))
      .slice(0, Math.max(1, Math.min(50, limit)));
    return {campaign_id:this.value.campaign_id, vault_updated_at:this.value.updated_at,
      records:ranked.map(({record}) => ({id:record.id, kind:record.kind, title:record.title,
        content:record.content, provenance:record.provenance}))};
  }

  async propose(input, source = 'chatgpt-context-bridge') {
    const proposal = normalizeRecord({...input, id:input.id || `proposal:${crypto.randomUUID()}`,
      status:'proposed', provenance:{source, authority:'awaiting_host_approval'}, proposed_at:new Date().toISOString()});
    this.value.proposals.push(proposal);
    await this.save();
    return proposal;
  }

  async review({proposal_id, action, reviewer = 'host'}) {
    const proposal = this.value.proposals.find(record => record.id === proposal_id && record.status === 'proposed');
    if (!proposal) throw new Error('That knowledge proposal is no longer pending.');
    if (!['approve', 'reject'].includes(action)) throw new Error('Choose approve or reject.');
    proposal.status = action === 'approve' ? 'approved' : 'rejected';
    proposal.reviewed_at = new Date().toISOString(); proposal.reviewed_by = reviewer;
    if (action === 'approve') {
      const prior = this.value.records.find(record => record.id === proposal.id);
      if (prior) prior.status = 'superseded';
      this.value.records.push(normalizeRecord({...proposal, status:'approved',
        provenance:{...proposal.provenance, authority:'host_approved'}}));
    }
    await this.save();
    return proposal;
  }

  async recordCommittedTurn(transaction) {
    const id = `turn:${transaction.transaction_id}`;
    if (this.value.records.some(record => record.id === id)) return;
    this.value.records.push(normalizeRecord({id, kind:'campaign_event', title:`Committed turn ${transaction.turn_id}`,
      content:{declaration:transaction.declaration, public_narration:transaction.public_narration,
        companion_lines:transaction.companion_lines || [], campaign_time_after:transaction.campaign_time_after,
        resulting_state_head:transaction.resulting_state_head}, visibility:'party', status:'approved',
      subject_ids:[], tags:['committed-turn','campaign-history'],
      provenance:{source:'wayfolio-contract-1.1', authority:'committed_campaign_history'}}));
    await this.save();
  }
}
