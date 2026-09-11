import {randomUUID} from 'node:crypto';

export class WorkspaceAgentTransportError extends Error {
  constructor(code, message, options = {}) {
    super(message, options);
    this.name = 'WorkspaceAgentTransportError';
    this.code = code;
  }
}

function requireText(value, name) {
  if (typeof value !== 'string' || !value.trim()) {
    throw new WorkspaceAgentTransportError('INVALID_REQUEST', `${name} is required.`);
  }
  return value.trim();
}

async function parseJSON(response) {
  try { return await response.json(); }
  catch (error) {
    throw new WorkspaceAgentTransportError('INVALID_RESPONSE', 'The Workspace Agent returned invalid JSON.', {cause:error});
  }
}

export class WorkspaceAgentStoryteller {
  constructor({
    accessToken = '',
    agentTriggerId = '',
    baseURL = 'https://api.chatgpt.com/v1',
    fetchImpl = fetch,
  } = {}) {
    this.accessToken = accessToken;
    this.agentTriggerId = agentTriggerId;
    this.baseURL = baseURL.replace(/\/$/, '');
    this.fetchImpl = fetchImpl;
  }

  configured() {
    return Boolean(this.accessToken && this.agentTriggerId);
  }

  async triggerTurn({turnId, conversationKey, input, idempotencyKey = turnId, signal} = {}) {
    requireText(this.accessToken, 'Workspace Agent access token');
    requireText(this.agentTriggerId, 'Workspace Agent trigger ID');
    requireText(turnId, 'turnId');
    requireText(conversationKey, 'conversationKey');
    requireText(input, 'input');
    requireText(idempotencyKey, 'idempotencyKey');

    let response;
    try {
      response = await this.fetchImpl(
        `${this.baseURL}/workspace_agents/${encodeURIComponent(this.agentTriggerId)}/trigger`,
        {
          method:'POST',
          signal,
          headers:{
            Authorization:`Bearer ${this.accessToken}`,
            'Content-Type':'application/json',
            'Idempotency-Key':idempotencyKey,
            'OpenAI-Beta':'workspace_agent_runs=v1',
            'X-Client-Request-Id':randomUUID(),
          },
          body:JSON.stringify({conversation_key:conversationKey, input}),
        },
      );
    } catch (error) {
      throw new WorkspaceAgentTransportError('NETWORK_UNAVAILABLE', 'Wayfolio could not reach the Workspace Agents service.', {cause:error});
    }

    if (response.status === 401 || response.status === 403) {
      throw new WorkspaceAgentTransportError('REAUTHORIZATION_REQUIRED', 'The Workspace Agent credential is invalid or lacks permission.');
    }
    if (response.status === 404) {
      throw new WorkspaceAgentTransportError('AGENT_NOT_FOUND', 'The published Workspace Agent trigger could not be found.');
    }
    if (response.status === 409) {
      throw new WorkspaceAgentTransportError('AGENT_NOT_RUNNABLE', 'The Workspace Agent is not currently runnable.');
    }
    if (response.status !== 202) {
      throw new WorkspaceAgentTransportError('PROVIDER_UNAVAILABLE', `Workspace Agent trigger failed (${response.status}).`);
    }

    const body = await parseJSON(response);
    return {
      turnId,
      idempotencyKey,
      conversationURL:typeof body.conversation_url === 'string' ? body.conversation_url : null,
      runId:typeof body.agent_trigger_run_id === 'string' ? body.agent_trigger_run_id : null,
      accepted:true,
    };
  }

  async getRunStatus(runId, {signal} = {}) {
    requireText(this.accessToken, 'Workspace Agent access token');
    requireText(this.agentTriggerId, 'Workspace Agent trigger ID');
    requireText(runId, 'runId');
    let response;
    try {
      response = await this.fetchImpl(
        `${this.baseURL}/workspace_agents/${encodeURIComponent(this.agentTriggerId)}/runs/${encodeURIComponent(runId)}`,
        {signal, headers:{Authorization:`Bearer ${this.accessToken}`}},
      );
    } catch (error) {
      throw new WorkspaceAgentTransportError('NETWORK_UNAVAILABLE', 'Wayfolio could not retrieve the Workspace Agent run status.', {cause:error});
    }
    if (response.status === 401 || response.status === 403) {
      throw new WorkspaceAgentTransportError('REAUTHORIZATION_REQUIRED', 'The Workspace Agent credential is invalid or lacks permission.');
    }
    if (!response.ok) {
      throw new WorkspaceAgentTransportError('PROVIDER_UNAVAILABLE', `Workspace Agent status request failed (${response.status}).`);
    }
    const body = await parseJSON(response);
    return {
      runId:body.id || runId,
      status:body.status || 'unknown',
      terminal:['completed', 'failed'].includes(body.status),
      conversationURL:body.conversation_url || null,
      error:body.error || null,
    };
  }
}
