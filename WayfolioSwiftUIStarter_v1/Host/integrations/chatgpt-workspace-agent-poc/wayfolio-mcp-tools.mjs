import {createHash} from 'node:crypto';
import {
  canViewVisibility,
  validateStorytellerContext,
  validateStorytellerTurn,
} from '../../storyteller-runtime.mjs';

function hash(value) {
  return createHash('sha256').update(JSON.stringify(value)).digest('hex');
}

function requireText(value, name) {
  if (typeof value !== 'string' || !value.trim()) throw new Error(`${name} is required.`);
  return value.trim();
}

function deliveryCounts(turn) {
  const publicSegments = turn.narrativeSegments.filter(item => ['PARTY', 'PUBLIC_SESSION'].includes(item.visibility.scope));
  const privateSegments = turn.narrativeSegments.filter(item => ['GM_ONLY', 'PLAYER_IDS', 'CHARACTER_IDS'].includes(item.visibility.scope));
  return {publicSegments:publicSegments.length, privateSegments:privateSegments.length};
}

export const WAYFOLIO_MCP_TOOL_DEFINITIONS = Object.freeze([
  {
    name:'wayfolio_get_turn_context',
    description:'Read the authoritative Wayfolio context for one registered turn before resolving it.',
    inputSchema:{type:'object', additionalProperties:false, required:['turn_id'], properties:{turn_id:{type:'string'}}},
  },
  {
    name:'wayfolio_publish_turn',
    description:'Submit one structured storyteller proposal. Wayfolio validates it; this tool does not directly mutate canonical campaign state.',
    inputSchema:{
      type:'object', additionalProperties:false, required:['turn_id', 'expected_state_revision', 'storyteller_turn'],
      properties:{
        turn_id:{type:'string'}, expected_state_revision:{type:'integer', minimum:0},
        storyteller_turn:{type:'object'},
      },
    },
  },
  {
    name:'wayfolio_report_failure',
    description:'Report that a registered Wayfolio turn could not be resolved.',
    inputSchema:{
      type:'object', additionalProperties:false, required:['turn_id', 'code', 'message'],
      properties:{turn_id:{type:'string'}, code:{type:'string'}, message:{type:'string'}},
    },
  },
]);

export class WayfolioMCPToolBridge {
  constructor({getCurrentStateRevision = () => 0, onValidatedTurn = async () => ({status:'VALIDATED'})} = {}) {
    this.getCurrentStateRevision = getCurrentStateRevision;
    this.onValidatedTurn = onValidatedTurn;
    this.turns = new Map();
    this.audit = [];
  }

  registerTurn(context) {
    const validation = validateStorytellerContext(context);
    if (!validation.valid) throw new Error(`Invalid StorytellerContext: ${validation.errors.join(', ')}`);
    const prior = this.turns.get(context.turnId);
    const fingerprint = hash(context);
    if (prior && prior.contextFingerprint !== fingerprint) throw new Error('turn_id was reused with different context.');
    if (!prior) this.turns.set(context.turnId, {context, contextFingerprint:fingerprint, publication:null, failure:null});
    return {turn_id:context.turnId, state_revision:context.stateVersion, registered:true};
  }

  async callTool(name, args = {}) {
    switch (name) {
      case 'wayfolio_get_turn_context': return this.getTurnContext(args);
      case 'wayfolio_publish_turn': return this.publishTurn(args);
      case 'wayfolio_report_failure': return this.reportFailure(args);
      default: throw new Error(`Unknown Wayfolio MCP tool: ${name}`);
    }
  }

  getTurnContext({turn_id:turnId} = {}) {
    requireText(turnId, 'turn_id');
    const record = this.turns.get(turnId);
    if (!record) throw new Error('Unknown or expired turn_id.');
    this.audit.push({at:new Date().toISOString(), type:'CONTEXT_READ', turnId});
    return {turn_id:turnId, authoritative:true, context:record.context};
  }

  async publishTurn({turn_id:turnId, expected_state_revision:expectedRevision, storyteller_turn:input} = {}) {
    requireText(turnId, 'turn_id');
    if (!Number.isInteger(expectedRevision) || expectedRevision < 0) throw new Error('expected_state_revision must be a non-negative integer.');
    const record = this.turns.get(turnId);
    if (!record) throw new Error('Unknown or expired turn_id.');

    const publicationFingerprint = hash({turnId, expectedRevision, input});
    if (record.publication) {
      if (record.publication.fingerprint !== publicationFingerprint) throw new Error('A completed turn_id was reused with different content.');
      return {...record.publication.receipt, replayed:true};
    }
    if (record.failure) throw new Error('This turn was already reported as failed.');

    const currentRevision = Number(await this.getCurrentStateRevision(record.context.sessionId));
    if (expectedRevision !== record.context.stateVersion || currentRevision !== record.context.stateVersion) {
      const receipt = {accepted:false, code:'STALE_STATE', turn_id:turnId, expected_state_revision:currentRevision};
      this.audit.push({at:new Date().toISOString(), type:'PUBLICATION_REJECTED', turnId, code:'STALE_STATE'});
      return receipt;
    }

    const validation = validateStorytellerTurn(input);
    if (!validation.valid) throw new Error(`Invalid StorytellerTurn: ${validation.errors.join(', ')}`);
    const turn = validation.value;
    if (turn.turnId !== turnId || turn.sessionId !== record.context.sessionId) throw new Error('Published turn does not match its registered context.');
    if (turn.basedOnStateVersion !== expectedRevision) throw new Error('Published turn is based on the wrong state revision.');

    // Exercise every visibility value now so malformed private/public routing cannot pass unnoticed.
    for (const segment of turn.narrativeSegments) {
      canViewVisibility(segment.visibility, {role:'host'});
    }

    const validationResult = await this.onValidatedTurn({context:record.context, turn});
    const receipt = {
      accepted:true,
      turn_id:turnId,
      state_revision:expectedRevision,
      proposal_status:validationResult?.status || 'VALIDATED',
      delivery_counts:deliveryCounts(turn),
      replayed:false,
    };
    record.publication = {fingerprint:publicationFingerprint, receipt, turn};
    this.audit.push({at:new Date().toISOString(), type:'PUBLICATION_VALIDATED', turnId, receipt});
    return receipt;
  }

  reportFailure({turn_id:turnId, code, message} = {}) {
    requireText(turnId, 'turn_id');
    requireText(code, 'code');
    requireText(message, 'message');
    const record = this.turns.get(turnId);
    if (!record) throw new Error('Unknown or expired turn_id.');
    if (record.publication) throw new Error('This turn was already published.');
    if (!record.failure) {
      record.failure = {code, message};
      this.audit.push({at:new Date().toISOString(), type:'TURN_FAILED', turnId, code, message});
    }
    return {accepted:true, turn_id:turnId, failure:record.failure};
  }

  auditLog() {
    return structuredClone(this.audit);
  }
}
