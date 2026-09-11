export const LOW_COST_MODELS = Object.freeze({
  routine:'gpt-5.6-luna',
  complex:'gpt-5.6-terra',
});

export const MODEL_TOKEN_PRICING_USD_PER_MILLION = Object.freeze({
  'gpt-5.6-luna':Object.freeze({input:0.20, cachedInput:0.02, output:1.20, cacheWriteMultiplier:1.25}),
  'gpt-5.6-terra':Object.freeze({input:2.00, cachedInput:0.20, output:12.00, cacheWriteMultiplier:1.25}),
});

const roundMoney = value => Math.round((Number(value) || 0) * 1_000_000) / 1_000_000;
const positiveInteger = value => Math.max(0, Math.floor(Number(value) || 0));

export function estimateTextTokens(...values) {
  const characters = values.reduce((total, value) => total + String(value || '').length, 0);
  // Deliberately conservative for a hard spending cap: ordinary English is usually
  // several characters per token, but reserving one token per character avoids
  // approving a request on an optimistic tokenizer estimate.
  return Math.max(1, characters);
}

export function normalizeResponseUsage(usage = {}) {
  const inputTokens = positiveInteger(usage.input_tokens);
  const details = usage.input_tokens_details || {};
  const cachedTokens = Math.min(inputTokens, positiveInteger(details.cached_tokens));
  const cacheWriteTokens = Math.min(inputTokens - cachedTokens, positiveInteger(details.cache_write_tokens));
  return {
    input_tokens:inputTokens,
    cached_input_tokens:cachedTokens,
    cache_write_tokens:cacheWriteTokens,
    uncached_input_tokens:Math.max(0, inputTokens - cachedTokens - cacheWriteTokens),
    output_tokens:positiveInteger(usage.output_tokens),
    reasoning_tokens:positiveInteger(usage.output_tokens_details?.reasoning_tokens),
    total_tokens:positiveInteger(usage.total_tokens) || inputTokens + positiveInteger(usage.output_tokens),
  };
}

export function estimateUsageCostUSD(model, usage = {}, pricing = MODEL_TOKEN_PRICING_USD_PER_MILLION) {
  const rates = pricing[model];
  if (!rates) return null;
  const value = normalizeResponseUsage(usage);
  const cost = value.uncached_input_tokens * rates.input
    + value.cached_input_tokens * rates.cachedInput
    + value.cache_write_tokens * rates.input * rates.cacheWriteMultiplier
    + value.output_tokens * rates.output;
  return roundMoney(cost / 1_000_000);
}

export class StorytellerBudgetError extends Error {
  constructor(message, detail = {}) {
    super(message); this.name = 'StorytellerBudgetError'; this.code = 'BUDGET_CAP_REACHED'; this.detail = detail;
  }
}

export class StorytellerCostPolicy {
  constructor({enabled = true, routineModel = LOW_COST_MODELS.routine, complexModel = LOW_COST_MODELS.complex,
    budgetUSD = 1, routineMaxOutputTokens = 1800, complexMaxOutputTokens = 2600,
    pricing = MODEL_TOKEN_PRICING_USD_PER_MILLION, now = () => new Date()} = {}) {
    this.enabled = Boolean(enabled); this.routineModel = routineModel; this.complexModel = complexModel;
    this.budgetUSD = Math.max(0.01, Number(budgetUSD) || 1); this.routineMaxOutputTokens = routineMaxOutputTokens;
    this.complexMaxOutputTokens = complexMaxOutputTokens; this.pricing = pricing; this.now = now;
    this.startedAt = this.now().toISOString(); this.spentUSD = 0; this.requests = 0;
    this.modelRequests = {}; this.tokens = {input:0,cached:0,cache_write:0,output:0}; this.reservations = new Map();
  }

  route(taskClass = 'routine') {
    const complex = taskClass === 'complex';
    return {task_class:complex ? 'complex' : 'routine', model:complex ? this.complexModel : this.routineModel,
      max_output_tokens:complex ? this.complexMaxOutputTokens : this.routineMaxOutputTokens};
  }

  reserve(id, {model, estimatedInputTokens = 1, maxOutputTokens = 1} = {}) {
    if (!this.enabled || !this.pricing[model]) return null;
    if (this.reservations.has(id)) return this.reservations.get(id);
    const maximumCostUSD = estimateUsageCostUSD(model, {input_tokens:estimatedInputTokens, output_tokens:maxOutputTokens}, this.pricing);
    const reservedUSD = [...this.reservations.values()].reduce((total, item) => total + item.maximum_cost_usd, 0);
    const projectedUSD = roundMoney(this.spentUSD + reservedUSD + maximumCostUSD);
    if (projectedUSD > this.budgetUSD) {
      throw new StorytellerBudgetError('The AI spending cap for this play session has been reached. Wayfolio will continue in its local fallback mode.',
        {spent_usd:this.spentUSD, reserved_usd:roundMoney(reservedUSD), request_maximum_usd:maximumCostUSD,
          budget_usd:this.budgetUSD, model});
    }
    const reservation = {id, model, maximum_cost_usd:maximumCostUSD}; this.reservations.set(id, reservation); return reservation;
  }

  settle(id, {model, usage} = {}) {
    this.reservations.delete(id);
    if (!this.enabled || !this.pricing[model]) return null;
    const normalized = normalizeResponseUsage(usage); const costUSD = estimateUsageCostUSD(model, usage, this.pricing);
    this.spentUSD = roundMoney(this.spentUSD + costUSD); this.requests += 1;
    this.modelRequests[model] = (this.modelRequests[model] || 0) + 1;
    this.tokens.input += normalized.input_tokens; this.tokens.cached += normalized.cached_input_tokens;
    this.tokens.cache_write += normalized.cache_write_tokens; this.tokens.output += normalized.output_tokens;
    return {model, usage:normalized, estimated_cost_usd:costUSD, session_spent_usd:this.spentUSD,
      session_budget_usd:this.budgetUSD, session_remaining_usd:roundMoney(Math.max(0, this.budgetUSD - this.spentUSD))};
  }

  release(id) { this.reservations.delete(id); }

  setBudget(budgetUSD) {
    const value = Number(budgetUSD);
    if (!Number.isFinite(value) || value < 0.01 || value > 100) throw new Error('Choose an AI play-session cap from $0.01 to $100.');
    this.budgetUSD = Math.round(value * 100) / 100; return this.status();
  }

  reset() {
    this.startedAt = this.now().toISOString(); this.spentUSD = 0; this.requests = 0;
    this.modelRequests = {}; this.tokens = {input:0,cached:0,cache_write:0,output:0}; this.reservations.clear();
    return this.status();
  }

  status() {
    return {enabled:this.enabled, strategy:'Luna for routine mechanics; Terra for character dialogue and complex encounters',
      routine_model:this.routineModel, complex_model:this.complexModel, spent_usd:roundMoney(this.spentUSD),
      budget_usd:this.budgetUSD, remaining_usd:roundMoney(Math.max(0, this.budgetUSD - this.spentUSD)),
      request_count:this.requests, model_requests:{...this.modelRequests}, tokens:{...this.tokens},
      reserved_usd:roundMoney([...this.reservations.values()].reduce((total, item) => total + item.maximum_cost_usd, 0)),
      started_at:this.startedAt};
  }
}
