import {createHash} from 'node:crypto';
import {canReceiveKnowledge, normalizeKnowledgeScope} from './gameplay-policy.mjs';

function text(value) { return String(value || '').trim(); }
function values(value) { return Array.isArray(value) ? value : []; }

export function stableKnowledgeRecordID(kind, identity) {
  const category = text(kind).toLowerCase().replace(/[^a-z0-9]+/g, '-') || 'record';
  const normalized = text(identity).toLowerCase().replace(/\s+/g, ' ');
  const digest = createHash('sha256').update(`${category}:${normalized}`).digest('hex').slice(0, 16);
  return `${category}-${digest}`;
}

export function normalizeKnowledgeRecords(records = []) {
  const normalized = [];
  for (const value of values(records)) {
    const kind = text(value?.kind) || 'discovery';
    const name = text(value?.name) || 'Discovery';
    const id = text(value?.id) || stableKnowledgeRecordID(kind, name);
    const notes = [...new Set(values(value?.notes).map(text).filter(Boolean))];
    const provenance = [...new Set(values(value?.provenance).map(text).filter(Boolean))];
    const existing = normalized.find(record => record.id === id);
    if (existing) {
      existing.notes = [...new Set([...existing.notes, ...notes])];
      existing.provenance = [...new Set([...existing.provenance, ...provenance])];
      existing.status = text(value?.status) || existing.status;
      existing.updated_at = value?.updated_at || existing.updated_at;
      continue;
    }
    normalized.push({
      id, kind, name, status:text(value?.status) || 'known', notes, provenance,
      knowledge_scope:normalizeKnowledgeScope(value?.knowledge_scope || 'CHARACTER'),
      owner_character_id:text(value?.owner_character_id || value?.character_id) || null,
      relevance:Number(value?.relevance || 0),
      created_at:value?.created_at || value?.updated_at || null,
      updated_at:value?.updated_at || value?.created_at || null,
    });
  }
  return normalized;
}

export function upsertKnowledgeRecord(records, value, now = new Date().toISOString()) {
  const normalized = normalizeKnowledgeRecords(records);
  const kind = text(value?.kind) || 'discovery';
  const name = text(value?.name) || 'Discovery';
  const id = text(value?.id) || stableKnowledgeRecordID(kind, value?.identity || name);
  const index = normalized.findIndex(record => record.id === id);
  const note = text(value?.note);
  const provenance = text(value?.provenance);
  if (index >= 0) {
    const prior = normalized[index];
    normalized[index] = {...prior,
      name:name || prior.name,
      status:text(value?.status) || prior.status,
      notes:[...new Set([...prior.notes, ...(note ? [note] : []), ...values(value?.notes).map(text).filter(Boolean)])],
      provenance:[...new Set([...prior.provenance, ...(provenance ? [provenance] : [])])],
      knowledge_scope:normalizeKnowledgeScope(value?.knowledge_scope || prior.knowledge_scope),
      owner_character_id:text(value?.owner_character_id || value?.character_id || prior.owner_character_id) || null,
      relevance:Math.max(Number(prior.relevance || 0), Number(value?.relevance || 0)),
      updated_at:now,
    };
    return {records:normalized, record:normalized[index], created:false};
  }
  const record = {id, kind, name, status:text(value?.status) || 'known',
    notes:[...new Set([...(note ? [note] : []), ...values(value?.notes).map(text).filter(Boolean)])],
    provenance:provenance ? [provenance] : [],
    knowledge_scope:normalizeKnowledgeScope(value?.knowledge_scope || 'CHARACTER'),
    owner_character_id:text(value?.owner_character_id || value?.character_id) || null,
    relevance:Number(value?.relevance || 0), created_at:now, updated_at:now};
  normalized.push(record);
  return {records:normalized, record, created:true};
}

export function mergeKnowledgeRecords(...collections) {
  return normalizeKnowledgeRecords(collections.flat());
}

export function filterKnowledgeRecordsForViewer(records, viewer) {
  return normalizeKnowledgeRecords(records).filter(record => canReceiveKnowledge(record, viewer))
    .sort((a, b) => Number(b.relevance || 0) - Number(a.relevance || 0)
      || Date.parse(b.updated_at || b.created_at || 0) - Date.parse(a.updated_at || a.created_at || 0));
}
