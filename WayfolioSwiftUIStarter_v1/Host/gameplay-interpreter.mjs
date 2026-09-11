const categories = {
  speech:/\b(ask|tell|say|speak|call|warn|promise|answer|reply|greet|apologize|thank)\b/i,
  exploration:/\b(look|listen|watch|inspect|examine|search|study|read|track|latch|bridge|door|trail|motes?|pollen|hinge)\b/i,
  travel:/\b(walk|move|cross|follow|race|run|climb|jump|reach|go|stand)\b/i,
  social:/\b(soren|lupin|gatekeeper|convince|persuade|comfort|threaten|ask|tell|race)\b/i,
  item_use:/\b(potion|kit|staff|item|give|drink|use)\b/i,
  magic:/\b(cast|spell|magic|healing word|druidcraft)\b/i,
  combat:/\b(attack|strike|fight|hound|dodge|brace|initiative)\b/i,
  assistance:/\b(help|assists?|compare.+notes|together)\b/i,
  rest:/\b(rest|sleep|camp)\b/i,
};

const impossiblePatterns = [
  /lift (?:the )?entire (?:stone )?bridge with one hand/i,
  /ask (?:the )?(?:ancient )?sealed door to open/i,
  /decipher (?:the )?sealed archmage notation/i,
];

const ordinaryPattern = /^(?:i |we )?(?:walk|move|stand|sit|wait|follow|close|open|hand|show|ask|tell|say|speak|call|greet|answer|reply|nod|smile|wave|introduce|apologize|thank)\b/i;
// The shared “Speak or act” box accepts natural dialogue, not only commands
// prefixed with “I ask”. Direct questions and conversational responses are
// ordinary speech unless their wording declares a consequential social tactic.
const directDialoguePattern = /^(?:["“])?(?:who|what|when|where|why|how|is|are|am|can|could|would|will|do|does|did|have|has|hello|hi|hey|yes|no|okay|thanks|thank you|please|let(?:'|’)s)\b/i;
const firstPersonDialoguePattern = /^i (?:do(?:n't|n’t| not)|did(?:n't|n’t| not)|have(?:n't|n’t| not)?|had(?:n't|n’t| not)?|think|believe|remember|know|feel|agree|disagree|mean|meant|said|told|would|could|can(?:not|'t|’t)?|won(?:'t|’t)|will not)\b/i;
const lowRiskObservationPattern = /^(?:i |we )?(?:look|listen|watch|inspect|examine|study|read|observe)\b/i;
const declaredActionPattern = /\b(?:attack|strike|fight|cast|use|drink|give|steal|hide|sneak|search|inspect|examine|study|track|force|break|climb|jump|run|race|grapple|heal|unlock|open|close|walk|move|follow|go|take)\b/i;
// A verb is not a stake. Looking, reading, examining, or studying should flow
// automatically when the fiction has not established concealment, pressure,
// opposition, danger, or a meaningful cost of failure.
const meaningfulRiskPattern = /\b(force|break|fragile|corroded|without snapping|pressure plate|danger|chase|escape|hide|sneak|convince|deceive|threaten|track|concealed|hidden|tiny inscription|through the smoke|driving rain)\b/i;

function unique(values) { return [...new Set(values)]; }

function inferCategories(text) {
  const found = Object.entries(categories).filter(([, pattern]) => pattern.test(text)).map(([name]) => name);
  if (/\b(recognize|whether|what can i plainly see|do i know)\b/i.test(text)) found.push('investigation');
  return unique(found.length ? found : ['unexpected']);
}

function skillFor(text, actor = {}) {
  if (/\b(pollen|herb|motes?|nature|plants?|trail)\b/i.test(text)) return 'Nature';
  if (/\b(track|tracks|watch|listen|search|look|observe|pressure plate|tool marks)\b/i.test(text)) return 'Perception';
  if (/\b(latch|hinge|mechanism|inscription|read|decipher)\b/i.test(text)) return 'Investigation';
  if (/\b(convince|persuade|gatekeeper|authentic)\b/i.test(text)) return 'Persuasion';
  if (/\b(race|grapple|wrestle|force|lift|climb|jump)\b/i.test(text)) return 'Athletics';
  if (/\b(hare|hound|soothe|calm|animal)\b/i.test(text)) return 'Animal Handling';
  if (/\b(heal|healer|wound|medicine)\b/i.test(text)) return 'Medicine';
  return actor.default_skill || 'Insight';
}

function baseDC(text) {
  if (/\b(corroded|tiny inscription|driving rain|wary gatekeeper)\b/i.test(text)) return 15;
  if (/\b(fragile|pressure plate|hidden|conceal|track)\b/i.test(text)) return 13;
  return 12;
}

function potionTargets(state) {
  return (state.present_entities || []).filter(entity => entity.id !== state.actor_id && entity.can_receive_items !== false);
}

function itemCandidates(state, kind = 'potion') {
  return (state.inventory || []).filter(item => String(item.kind || item.name || '').toLowerCase().includes(kind));
}

function clarification(text, state) {
  if (/\bi give them the potion\b/i.test(text)) {
    const targets = potionTargets(state);
    if (targets.length > 1) return {ambiguities:targets.map(target => ({kind:'target', ref:target.id})),
      question:`Do you give the potion to ${targets.map(target => target.name).join(' or ')}?`};
  }
  if (/\bi drink the potion\b/i.test(text)) {
    const items = itemCandidates(state);
    if (items.length > 1) return {ambiguities:items.map(item => ({kind:'resource', ref:item.id})),
      question:`Which potion do you drink: ${items.map(item => item.name).join(' or ')}?`};
  }
  return null;
}

function referencedTargets(text, state) {
  return (state.present_entities || []).filter(entity => {
    const names = unique([entity.name, String(entity.name || '').split(/\s+/)[0]]).filter(Boolean);
    return names.some(name => new RegExp(`\\b${String(name).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i').test(text));
  }).map(entity => entity.id);
}

function assistance(text, state) {
  const helper = (state.present_entities || []).find(entity => {
    const names = unique([entity.name, String(entity.name || '').split(/\s+/)[0]]).filter(Boolean);
    return names.some(name => new RegExp(`(?:with ${name}(?:'s|’s)?|${name} (?:helps|compares)|helped by ${name})`, 'i').test(text));
  });
  if (!helper) return null;
  const specialized = /sealed archmage notation/i.test(text);
  const capable = !specialized || helper.capabilities?.includes('arcane_literacy');
  return {helper, capable, source:capable ? `${helper.name} provides a plausible declared contribution` : null};
}

function advantageState(text, state) {
  const sources = [], hindrances = [];
  const helper = assistance(text, state);
  if (helper?.capable) sources.push(helper.source);
  if (/map marks i made here yesterday/i.test(text) && state.established_map_marks) sources.push('Renn’s established map marks directly aid navigation');
  if (/fresh trail markers/i.test(text) && state.valid_trail_markers) sources.push('Lupin’s valid fresh trail markers');
  if (/through the smoke/i.test(text) && state.heavy_smoke) hindrances.push('Heavy smoke obscures fine detail');
  if (/driving rain/i.test(text) && state.driving_rain) hindrances.push('Driving rain interferes with tracking');
  return {state:sources.length && hindrances.length ? 'normal' : sources.length ? 'advantage' : hindrances.length ? 'disadvantage' : 'normal',
    advantage_sources:sources, disadvantage_sources:hindrances};
}

export function interpretDeclaration(input) {
  const exact = String(input.declaration ?? '');
  const text = exact.trim();
  const state = input.state || {};
  const actor = input.actor || {};
  const visibility = input.visibility === 'private' ? 'private' : 'public';
  const inferredCategories = inferCategories(text);
  const ambiguity = clarification(text, {...state, actor_id:actor.id});
  const helper = assistance(text, state);
  const advantage = advantageState(text, state);
  const intent = `attempts to ${text.replace(/^i\s+/i, '')}`;
  const result = {
    protocol:'wayfolio.interpretation.v1', exact_declaration:exact, actor_id:actor.id,
    intent_summary:intent, target_refs:referencedTargets(text, state), desired_outcome:text, approach:text,
    categories:inferredCategories, visibility, assumptions:[], resource_candidates:[], known_risks:[],
    ambiguities:ambiguity?.ambiguities || [], clarification_required:Boolean(ambiguity),
    clarification_question:ambiguity?.question || null, confidence:ambiguity ? 'ambiguous' : 'high',
    resolution:{kind:'check', skill:skillFor(text, actor), dc:baseDC(text), target_kind:'dc',
      advantage_state:advantage.state, advantage_sources:advantage.advantage_sources,
      disadvantage_sources:advantage.disadvantage_sources, secret:false},
  };

  if (ambiguity) { result.resolution = {kind:'clarification'}; return result; }
  if (impossiblePatterns.some(pattern => pattern.test(text))) {
    result.resolution = {kind:'impossible', reason:'The desired outcome is not feasible by the declared method under established fiction.'};
    if (/decipher/i.test(text) && helper && !helper.capable) result.assumptions.push(`${helper.helper.name} lacks the required specialized arcane literacy.`);
    return result;
  }
  if (/\bkeep my footing|brace against|resist|shake off\b/i.test(text) && state.involuntary_threat) {
    result.resolution = {kind:'saving_throw', ability:state.save_ability || 'Dexterity', dc:state.save_dc || 12,
      target_kind:'dc', advantage_state:'normal', advantage_sources:[], disadvantage_sources:[], secret:false};
    result.known_risks = state.known_risks || [];
    return result;
  }
  const raceTarget = (state.present_entities || []).find(entity => entity.id !== actor.id && entity.name
    && new RegExp(`\\brace\\s+${String(entity.name).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i').test(text));
  if (raceTarget && state.contest_accepted) {
    const target = raceTarget;
    result.target_refs = target ? [target.id] : [];
    result.resolution = {kind:'opposed_check', skill:'Athletics', target_actor_id:target?.id || null,
      target_kind:'opposed_total', advantage_state:advantage.state, advantage_sources:advantage.advantage_sources,
      disadvantage_sources:advantage.disadvantage_sources, secret:false};
    return result;
  }
  if (/\bfalling lantern\b/i.test(text) && state.moment_by_moment_order_matters) {
    result.resolution = {kind:'initiative', reason:'Opposed actors require moment-by-moment ordering.'};
    return result;
  }
  if (/\bplainly see|from my herbalist training|commonly medicinal|already know\b/i.test(text)
      && (state.plainly_visible || state.actor_known_information)) {
    result.resolution = {kind:'information', information_scope:visibility === 'private' ? 'actor_private' : 'public'};
    return result;
  }
  if (/\bhold still and watch the crown hare\b/i.test(text) && !state.hostile_action_active) {
    result.resolution = {kind:state.plainly_visible ? 'information' : 'check',
      ...(state.plainly_visible ? {information_scope:'public'} : {skill:'Perception',dc:12,target_kind:'dc',advantage_state:'normal',advantage_sources:[],disadvantage_sources:[],secret:false})};
    return result;
  }
  const conversationalStatement = !/^(?:i|we)\b/i.test(text) && !declaredActionPattern.test(text);
  if (((ordinaryPattern.test(text) || lowRiskObservationPattern.test(text) || directDialoguePattern.test(text) || firstPersonDialoguePattern.test(text)
      || text.includes('?') || conversationalStatement)
      && !meaningfulRiskPattern.test(text)
      && !advantage.advantage_sources.length && !advantage.disadvantage_sources.length)
      || /\bask soren whether she recognizes\b/i.test(text)) {
    result.resolution = {kind:'automatic'};
    return result;
  }
  if (helper && !helper.capable) result.assumptions.push(`${helper.helper.name} cannot provide the specialized access required.`);
  if (/\bwary gatekeeper\b|\binvitation is authentic\b/i.test(text)) result.resolution.target_kind = 'dc';
  return result;
}

export function validateInterpretation(value) {
  const errors = [];
  if (!value || value.protocol !== 'wayfolio.interpretation.v1') errors.push('protocol');
  if (typeof value?.exact_declaration !== 'string') errors.push('exact_declaration');
  if (!value?.actor_id) errors.push('actor_id');
  if (!value?.intent_summary?.startsWith('attempts to ')) errors.push('intent_summary');
  if (!Array.isArray(value?.categories) || !value.categories.length) errors.push('categories');
  if (!['public','private'].includes(value?.visibility)) errors.push('visibility');
  if (!value?.resolution?.kind) errors.push('resolution.kind');
  return {valid:errors.length === 0, errors};
}
