import assert from 'node:assert/strict';
import {estimateUsageCostUSD, normalizeResponseUsage, StorytellerCostPolicy} from './storyteller-cost-policy.mjs';
import {OpenAIStorytellerTransport} from './storyteller-transport.mjs';

const usage = {input_tokens:1000, input_tokens_details:{cached_tokens:200,cache_write_tokens:100},
  output_tokens:500, output_tokens_details:{reasoning_tokens:25}, total_tokens:1500};
assert.deepEqual(normalizeResponseUsage(usage), {input_tokens:1000,cached_input_tokens:200,cache_write_tokens:100,
  uncached_input_tokens:700,output_tokens:500,reasoning_tokens:25,total_tokens:1500});
assert.equal(estimateUsageCostUSD('gpt-5.6-luna', usage), 0.000769);

let calls = 0; const requests = [];
const mockFetch = async (url, options = {}) => {
  if (url.endsWith('/models')) return new Response(JSON.stringify({data:[]}), {status:200});
  calls += 1; const request = JSON.parse(options.body); requests.push(request);
  return new Response(JSON.stringify({id:`resp-${calls}`,output_text:'A careful answer.',usage}),
    {status:200,headers:{'x-request-id':`req-${calls}`}});
};

const policy = new StorytellerCostPolicy({budgetUSD:0.01});
const transport = new OpenAIStorytellerTransport({apiKey:'sk-test-12345678901234567890',fetchImpl:mockFetch,costPolicy:policy});
transport.setState('ACTIVE');
const routine = await transport.generate({idempotencyKey:'routine-1',messageType:'StorytellerContext',
  payload:{declaration:'I listen at the bridge.'},instructions:'Continue open play.',taskClass:'routine',promptCacheKey:'wayfolio:HEMLOCK'});
assert.equal(routine.model, 'gpt-5.6-luna');
assert.equal(requests[0].model, 'gpt-5.6-luna');
assert.equal(requests[0].max_output_tokens, 1800);
assert.equal(requests[0].prompt_cache_key, 'wayfolio:HEMLOCK');
assert.deepEqual(requests[0].prompt_cache_options, {ttl:'30m'});
assert.equal(routine.cost.estimated_cost_usd, 0.000769);
assert.equal(policy.status().request_count, 1);

const replay = await transport.generate({idempotencyKey:'routine-1',messageType:'StorytellerContext',
  payload:{declaration:'I listen at the bridge.'},instructions:'Continue open play.',taskClass:'routine',promptCacheKey:'wayfolio:HEMLOCK'});
assert.equal(replay.replayed, true); assert.equal(calls, 1); assert.equal(policy.status().request_count, 1);

await assert.rejects(() => transport.generate({idempotencyKey:'complex-1',messageType:'StorytellerContext',
  payload:{declaration:'I enter the monster encounter.'},instructions:'Continue open play.',taskClass:'complex'}),
  error => error.code === 'BUDGET_CAP_REACHED');
assert.equal(calls, 1, 'A request that cannot fit beneath the cap must never reach the provider.');
assert.equal(transport.publicStatus().state, 'BUDGET_PAUSED');
assert.equal(policy.status().spent_usd, 0.000769);

policy.setBudget(1); policy.reset(); transport.setState('ACTIVE');
const complex = await transport.generate({idempotencyKey:'complex-2',messageType:'StorytellerContext',
  payload:{declaration:'I enter the monster encounter.'},instructions:'Continue open play.',taskClass:'complex'});
assert.equal(complex.model, 'gpt-5.6-terra'); assert.equal(requests[1].max_output_tokens, 2600);
assert.equal(policy.status().model_requests['gpt-5.6-terra'], 1);

console.log('Wayfolio low-cost storyteller tests passed.');
