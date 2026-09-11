import {createHash, randomUUID} from 'node:crypto';
import {estimateTextTokens, StorytellerBudgetError} from './storyteller-cost-policy.mjs';

export const STORYTELLER_TRANSPORT_STATES = Object.freeze({
  DISCONNECTED:'DISCONNECTED', CONNECTING:'CONNECTING', ACTIVE:'ACTIVE',
  GENERATING:'GENERATING', SLOW:'SLOW', RECONNECTING:'RECONNECTING',
  REAUTHORIZATION_REQUIRED:'REAUTHORIZATION_REQUIRED', UNAVAILABLE:'UNAVAILABLE',
  BUDGET_PAUSED:'BUDGET_PAUSED',
});

function hash(value) { return createHash('sha256').update(JSON.stringify(value)).digest('hex'); }
function responseText(body) {
  if (typeof body?.output_text === 'string') return body.output_text;
  for (const item of body?.output || []) for (const content of item.content || []) {
    if (typeof content.text === 'string') return content.text;
  }
  return '';
}

export class StorytellerTransportError extends Error {
  constructor(code, message, options = {}) { super(message, options); this.name = 'StorytellerTransportError'; this.code = code; }
}

export class OpenAIStorytellerTransport {
  constructor({apiKey = '', source = 'none', model = 'gpt-5-mini', baseURL = 'https://api.openai.com/v1',
    fetchImpl = fetch, onState = () => {}, softTimeoutMs = 10_000, hardTimeoutMs = 45_000, costPolicy = null} = {}) {
    this.apiKey = apiKey; this.source = source; this.model = model; this.baseURL = baseURL.replace(/\/$/, '');
    this.fetchImpl = fetchImpl; this.onState = onState; this.softTimeoutMs = softTimeoutMs; this.hardTimeoutMs = hardTimeoutMs;
    this.state = apiKey ? STORYTELLER_TRANSPORT_STATES.RECONNECTING : STORYTELLER_TRANSPORT_STATES.DISCONNECTED;
    this.pending = new Map(); this.completed = new Map(); this.lastError = null; this.lastRequestId = null;
    this.costPolicy = costPolicy;
    this.connectionId = apiKey ? randomUUID() : null; this.accountLabel = apiKey ? `OpenAI API · ••••${apiKey.slice(-4)}` : null;
  }

  publicStatus({privateHost = false} = {}) {
    const base = {state:this.state, active:this.state === STORYTELLER_TRANSPORT_STATES.ACTIVE,
      mode:this.apiKey && this.state !== STORYTELLER_TRANSPORT_STATES.BUDGET_PAUSED ? 'Live AI Storyteller' : 'Local Play',
      pending_turns:this.pending.size};
    if (privateHost) Object.assign(base, {provider:'openai_api', configured:Boolean(this.apiKey),
      model:this.apiKey ? this.model : null, last_error_code:this.lastError?.code || null,
      low_cost_mode:this.costPolicy?.status?.() || null, source:this.source, account_label:this.accountLabel,
      connection_id:this.connectionId, key_hint:this.apiKey ? `••••${this.apiKey.slice(-4)}` : null,
      constraint:'OpenAI supports server-side API credentials; it does not expose direct binding to a personal ChatGPT account or existing ChatGPT conversation.'});
    return base;
  }

  setState(state, detail = null) {
    this.state = state; this.lastError = detail instanceof Error ? detail : null;
    this.onState(this.publicStatus(), detail);
  }

  async verifyKey(apiKey, {signal} = {}) {
    let response;
    try {
      response = await this.fetchImpl(`${this.baseURL}/models`, {signal,
        headers:{Authorization:`Bearer ${apiKey}`, 'X-Client-Request-Id':randomUUID()}});
    } catch (error) {
      throw new StorytellerTransportError('NETWORK_UNAVAILABLE', 'Wayfolio could not reach the OpenAI API.', {cause:error});
    }
    if (response.status === 401 || response.status === 403) {
      throw new StorytellerTransportError('REAUTHORIZATION_REQUIRED', 'OpenAI rejected this API credential.');
    }
    if (!response.ok) throw new StorytellerTransportError('PROVIDER_UNAVAILABLE', `OpenAI verification failed (${response.status}).`);
    return true;
  }

  async connect({apiKey, source = 'saved', accountLabel} = {}) {
    if (!apiKey) throw new StorytellerTransportError('CREDENTIAL_REQUIRED', 'An OpenAI API key is required.');
    this.setState(STORYTELLER_TRANSPORT_STATES.CONNECTING);
    try {
      await this.verifyKey(apiKey, {signal:AbortSignal.timeout(15_000)});
      this.apiKey = apiKey; this.source = source; this.connectionId = randomUUID();
      this.accountLabel = accountLabel || `OpenAI API · ••••${apiKey.slice(-4)}`;
      this.lastError = null; this.setState(STORYTELLER_TRANSPORT_STATES.ACTIVE);
      return this.publicStatus({privateHost:true});
    } catch (error) {
      this.setState(error.code === 'REAUTHORIZATION_REQUIRED'
        ? STORYTELLER_TRANSPORT_STATES.REAUTHORIZATION_REQUIRED : STORYTELLER_TRANSPORT_STATES.UNAVAILABLE, error);
      throw error;
    }
  }

  async replace({apiKey, accountLabel} = {}) {
    if (this.pending.size) throw new StorytellerTransportError('TURN_IN_PROGRESS', 'Finish or cancel the current storyteller turn before changing the account.');
    const prior = {apiKey:this.apiKey, source:this.source, connectionId:this.connectionId,
      accountLabel:this.accountLabel, state:this.state, lastError:this.lastError};
    try {
      await this.verifyKey(apiKey, {signal:AbortSignal.timeout(15_000)});
      this.apiKey = apiKey; this.source = 'saved'; this.connectionId = randomUUID();
      this.accountLabel = accountLabel || `OpenAI API · ••••${apiKey.slice(-4)}`;
      this.completed.clear(); this.lastError = null; this.setState(STORYTELLER_TRANSPORT_STATES.ACTIVE);
      return this.publicStatus({privateHost:true});
    } catch (error) {
      Object.assign(this, prior); this.onState(this.publicStatus(), error); throw error;
    }
  }

  disconnect({cancelPending = false} = {}) {
    if (this.pending.size && !cancelPending) throw new StorytellerTransportError('TURN_IN_PROGRESS', 'Finish or explicitly cancel the current storyteller turn before disconnecting.');
    if (cancelPending) this.pending.clear();
    this.apiKey = ''; this.source = 'none'; this.connectionId = null; this.accountLabel = null;
    this.completed.clear(); this.lastError = null; this.setState(STORYTELLER_TRANSPORT_STATES.DISCONNECTED);
    return this.publicStatus({privateHost:true});
  }

  async recover() {
    if (!this.apiKey) {
      this.setState(STORYTELLER_TRANSPORT_STATES.REAUTHORIZATION_REQUIRED,
        new StorytellerTransportError('REAUTHORIZATION_REQUIRED', 'Reconnect an OpenAI API credential on the private host.'));
      return this.publicStatus({privateHost:true});
    }
    this.setState(STORYTELLER_TRANSPORT_STATES.RECONNECTING);
    try { await this.verifyKey(this.apiKey, {signal:AbortSignal.timeout(15_000)}); this.setState(STORYTELLER_TRANSPORT_STATES.ACTIVE); }
    catch (error) { this.setState(error.code === 'REAUTHORIZATION_REQUIRED' ? STORYTELLER_TRANSPORT_STATES.REAUTHORIZATION_REQUIRED : STORYTELLER_TRANSPORT_STATES.UNAVAILABLE, error); }
    return this.publicStatus({privateHost:true});
  }

  async generate({idempotencyKey, messageType, payload, instructions, schema, taskClass = 'routine', promptCacheKey = null}) {
    if (!this.apiKey) throw new StorytellerTransportError('REAUTHORIZATION_REQUIRED', 'The live storyteller is not connected.');
    const route = this.costPolicy?.route(taskClass) || {task_class:taskClass, model:this.model, max_output_tokens:null};
    const fingerprint = hash({messageType, payload, instructions, schema, route, promptCacheKey});
    const completed = this.completed.get(idempotencyKey);
    if (completed) {
      if (completed.fingerprint !== fingerprint) throw new StorytellerTransportError('IDEMPOTENCY_CONFLICT', 'This storyteller request ID was reused with different content.');
      return {...completed.result, replayed:true};
    }
    const pending = this.pending.get(idempotencyKey);
    if (pending) {
      if (pending.fingerprint !== fingerprint) throw new StorytellerTransportError('IDEMPOTENCY_CONFLICT', 'This pending storyteller request ID was reused with different content.');
      return pending.promise;
    }
    const promise = this.#request({idempotencyKey, messageType, payload, instructions, schema, fingerprint, route, promptCacheKey});
    this.pending.set(idempotencyKey, {fingerprint, promise});
    try { return await promise; } finally { this.pending.delete(idempotencyKey); }
  }

  async #request({idempotencyKey, messageType, payload, instructions, schema, fingerprint, route, promptCacheKey}) {
    this.setState(STORYTELLER_TRANSPORT_STATES.GENERATING);
    const controller = new AbortController();
    const softTimer = setTimeout(() => this.setState(STORYTELLER_TRANSPORT_STATES.SLOW), this.softTimeoutMs); softTimer.unref?.();
    const hardTimer = setTimeout(() => controller.abort(new Error('hard timeout')), this.hardTimeoutMs); hardTimer.unref?.();
    try {
      const input = JSON.stringify({messageType, ...payload});
      this.costPolicy?.reserve(idempotencyKey, {model:route.model,
        estimatedInputTokens:estimateTextTokens(instructions, input, JSON.stringify(schema || {})),
        maxOutputTokens:route.max_output_tokens || 4096});
      const body = {model:route.model, store:false, instructions, input};
      if (route.max_output_tokens) body.max_output_tokens = route.max_output_tokens;
      if (promptCacheKey) {
        body.prompt_cache_key = promptCacheKey;
        body.prompt_cache_options = {ttl:'30m'};
      }
      if (schema) body.text = {format:{type:'json_schema', name:'wayfolio_storyteller_turn', strict:true, schema}};
      const response = await this.fetchImpl(`${this.baseURL}/responses`, {method:'POST', signal:controller.signal,
        headers:{'Content-Type':'application/json', Authorization:`Bearer ${this.apiKey}`, 'X-Client-Request-Id':idempotencyKey},
        body:JSON.stringify(body)});
      this.lastRequestId = response.headers?.get?.('x-request-id') || null;
      if (response.status === 401 || response.status === 403) throw new StorytellerTransportError('REAUTHORIZATION_REQUIRED', 'OpenAI authorization expired or was revoked.');
      if (response.status === 429) throw new StorytellerTransportError('RATE_LIMITED', 'The storyteller is temporarily rate limited.');
      if (!response.ok) throw new StorytellerTransportError('PROVIDER_UNAVAILABLE', `OpenAI storyteller request failed (${response.status}).`);
      const raw = await response.json(); const output = responseText(raw).trim();
      const value = schema ? JSON.parse(output) : output;
      const cost = this.costPolicy?.settle(idempotencyKey, {model:route.model, usage:raw.usage}) || null;
      const result = {value, provider_response_id:raw.id || null, request_id:this.lastRequestId, replayed:false,
        model:route.model, task_class:route.task_class, cost};
      this.completed.set(idempotencyKey, {fingerprint, result});
      if (this.completed.size > 200) this.completed.delete(this.completed.keys().next().value);
      this.setState(STORYTELLER_TRANSPORT_STATES.ACTIVE); return result;
    } catch (error) {
      this.costPolicy?.release(idempotencyKey);
      const normalized = error instanceof StorytellerTransportError ? error
        : error instanceof StorytellerBudgetError ? new StorytellerTransportError(error.code, error.message, {cause:error})
        : error?.name === 'AbortError' ? new StorytellerTransportError('TIMEOUT_UNCERTAIN', 'The storyteller request timed out; Wayfolio will reconcile before retrying.', {cause:error})
          : new StorytellerTransportError('INVALID_RESPONSE', error.message || 'The storyteller returned an invalid response.', {cause:error});
      this.setState(normalized.code === 'REAUTHORIZATION_REQUIRED' ? STORYTELLER_TRANSPORT_STATES.REAUTHORIZATION_REQUIRED
        : normalized.code === 'BUDGET_CAP_REACHED' ? STORYTELLER_TRANSPORT_STATES.BUDGET_PAUSED
          : STORYTELLER_TRANSPORT_STATES.UNAVAILABLE, normalized);
      throw normalized;
    } finally { clearTimeout(softTimer); clearTimeout(hardTimer); }
  }
}
