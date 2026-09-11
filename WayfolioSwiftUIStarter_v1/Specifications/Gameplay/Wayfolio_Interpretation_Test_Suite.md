# Wayfolio Gameplay Interpretation Test Suite

**Status:** Implementation-ready verification specification  
**Authority:** *Wayfolio Hands-Off AI Dungeon Master — Codex Implementation Packet*  
**Campaign fixture:** A disposable copy of Hemlock Development  
**Rules posture:** Fiction-first, 5E-compatible  

## 1. Purpose and execution rules

This suite verifies interpretation and routing, not predetermined story content. Generated narration may vary, but the locked interpretation, mechanic, authorization, state invariants, and prohibited behavior must satisfy every assertion.

All substantive tests must:

1. begin from a manifest-validated disposable campaign copy;
2. preserve `exact_declaration` byte-for-byte;
3. assign stable `client_action_id`, `action_id`, and `ruling_id` values;
4. persist every durable boundary before its acknowledgement;
5. inspect serialized WebSocket payloads, snapshots, journal events, model inputs, and Contract 1.1 transactions where applicable;
6. assert that no narration becomes canonical before an atomic commit; and
7. rerun the action or roll submission with the same client ID to prove idempotency.

Variable outcomes are expressed as consequence envelopes. Tests must not require a particular improvised plot outcome unless the result is mechanically forced by the fixture.

## 2. Shared fixtures

### F-HB-01 — Southern Hemlock Bridge

- Renn, Soren, and Lupin are present beneath the southern bridge at evening.
- Blue motes are plainly visible beneath the southern rail.
- A Crown Hare has been glimpsed near the fern line.
- One clue remains sealed and unavailable to public projections.
- No initiative is active.
- Renn: HP 10/10, AC 15, Strength −1, Dexterity +3, Wisdom +3; Animal Handling +5, Medicine +5, Nature +3, Perception +5.
- Soren: HP 9/9; Medicine +4, Nature +4, Perception +2, Persuasion +4.
- Lupin: HP 11/11; Athletics +3, Nature +3, Perception +5, Stealth +5, Survival +5.

### F-EN-01 — Gloam Hound encounter

- A Gloam Hound blocks a narrow rootway.
- Renn, Soren, Lupin, and the hound are aware of one another.
- Distance, cover, AC, HP, attacks, conditions, and initiative modifiers are loaded from authoritative encounter records.
- No creature has acted and no initiative order exists.

### F-RS-01 — Resources and equipment

- Renn possesses one Potion of Healing brewed by Renn, a healer's kit, staff, kunai, herbalist's kit, and Wayfolio.
- No standing permission allows Soren or Lupin to spend Renn's limited resources.
- Renn is wounded to 4/10 HP only in tests that explicitly reference this fixture.

### F-PR-01 — Privacy clients

- Authenticated clients: Renn Wayfolio, Soren player test client, shared screen, and private host.
- The shared screen is not authorized for private declaration text, private skill/DC data, secret arithmetic, or private discoveries.
- Other-player clients are not authorized for Renn-private information.

## 3. Required assertion shape

Each automated case should emit a structured expected record containing:

```yaml
test_id: WI-000
exact_declaration: "verbatim player text"
interpretation:
  intent_summary: "attempts to…"
  targets: []
  desired_outcome: ""
  approach: ""
  categories: []
  assumptions: []
  resource_candidates: []
  clarification_required: false
resolution:
  kind: automatic | information | check | opposed_check | saving_throw | attack | initiative | impossible
  mechanic: null
  visibility: public | actor_private | host_secret
stakes:
  success_envelope: ""
  failure_envelope: ""
prohibited: []
acceptance: []
```

## 4. Interpretation cases

### WI-001 — Ordinary feasible action resolves automatically

- **Exact declaration:** `I walk over to Soren and stand beside her.`
- **Relevant state:** F-HB-01; path is unobstructed and no time pressure exists.
- **Expected interpretation:** Renn attempts to move beside Soren; target Soren; approach ordinary movement; categories `travel`, `social`; no resource candidates or consequential assumptions.
- **Clarification:** No.
- **Resolution:** `automatic`; no roll or DC; public.
- **Expected stakes:** Renn reaches the feasible position; established world reactions or trivial elapsed time may be recorded, but failure is not manufactured.
- **Prohibited behavior:** Athletics check; movement menu; invented dialogue, emotion, or motive for Renn.
- **Acceptance criteria:** Exact declaration is durably acknowledged; no `roll_requested`; one validated transaction at most; open prompt returns.

### WI-002 — Plain sensory information is automatic

- **Exact declaration:** `I look at the blue motes beneath the rail. What can I plainly see?`
- **Relevant state:** F-HB-01; motes are illuminated and unobscured.
- **Expected interpretation:** Renn attempts visual observation of obvious features; categories `investigation`, `exploration`.
- **Clarification:** No.
- **Resolution:** `information`; no roll; public information only.
- **Expected stakes:** Provide baseline visible facts needed for an informed choice; do not provide sealed cause, motive, or conclusion.
- **Prohibited behavior:** Perception check merely to continue; revealing the sealed clue; stating what Renn realizes or believes.
- **Acceptance criteria:** Response contains only public/character-known facts and does not expose sealed records in payloads or model input.

### WI-003 — Background knowledge is automatic and private-capable

- **Exact declaration:** `From my herbalist training, do I recognize whether this pollen is commonly medicinal?`
- **Relevant state:** Renn's background includes Hemlock herbalism; the pollen's common classification is established and actor-known.
- **Expected interpretation:** Renn requests established professional knowledge; categories `investigation`; target pollen.
- **Clarification:** No.
- **Resolution:** `information`; actor-private if submitted privately, otherwise public.
- **Expected stakes:** Return only established background knowledge, not hidden supernatural origin.
- **Prohibited behavior:** Nature roll for already-known material; inventing a recipe; sharing private submission by implication.
- **Acceptance criteria:** No roll; visibility is inherited and never broadened.

### WI-004 — Meaningful uncertain ability check

- **Exact declaration:** `I test the old bridge latch to see whether I can open it without snapping the corroded mechanism.`
- **Relevant state:** Mechanism is fragile, operable, and under time pressure; both success and complication matter.
- **Expected interpretation:** Renn attempts careful manipulation while preserving the latch; target bridge latch; categories `exploration`; no resource spending.
- **Clarification:** No.
- **Resolution:** `check`; mechanic chosen for declared careful manipulation, with DC and all modifiers locked before dice; public.
- **Expected stakes:** Success envelope permits opening without breakage; failure envelope permits delay, noise, partial movement, or worsening corrosion, but not unrelated damage or automatic story blockage.
- **Prohibited behavior:** Substituting brute force; choosing a skill to optimize Renn; changing DC after seeing dice.
- **Acceptance criteria:** `ruling_locked_at` precedes roll evidence; transparent ordered arithmetic; one commit.

### WI-005 — Involuntary threat uses a saving throw

- **Exact declaration:** `I keep my footing as the bridge lurches beneath me.`
- **Relevant state:** A mechanically established sudden bridge shift involuntarily threatens Renn.
- **Expected interpretation:** Renn attempts to resist forced loss of footing; categories `exploration`; known risk is falling prone or being displaced.
- **Clarification:** No.
- **Resolution:** `saving_throw`; appropriate authoritative save and DC; public unless the threat itself is hidden.
- **Expected stakes:** Success resists the forced effect; failure applies only the locked bridge-hazard envelope.
- **Prohibited behavior:** Athletics check for an involuntary resistance if a save applies; adding damage not present in the locked hazard.
- **Acceptance criteria:** Save proficiency/conditions are sourced from character state and calculation is visible.

### WI-006 — Advantage from a strong established circumstance

- **Exact declaration:** `I follow the glowing trail using the map marks I made here yesterday.`
- **Relevant state:** Renn's accurate prior map marks are established and directly aid this navigation task.
- **Expected interpretation:** Renn attempts to follow the trail using established mapping aids; categories `travel`, `investigation`.
- **Clarification:** No.
- **Resolution:** `check` with advantage; relevant skill and fixed DC locked; public.
- **Expected stakes:** Success advances navigation; failure creates a proportionate route/time/exposure complication.
- **Prohibited behavior:** Both lowering DC and granting advantage for the same map benefit; stacking multiple advantage dice.
- **Acceptance criteria:** Source text names the map marks; two d20 values are recorded; highest is selected.

### WI-007 — Disadvantage from an established impediment

- **Exact declaration:** `I try to read the tiny inscription through the smoke without moving closer.`
- **Relevant state:** Smoke heavily obscures fine detail but does not make the attempt impossible.
- **Expected interpretation:** Renn attempts distant visual reading through smoke; categories `investigation`.
- **Clarification:** No.
- **Resolution:** `check` with disadvantage; public.
- **Expected stakes:** Success may identify readable surface detail; failure may cost time or leave uncertainty, not invent a false inscription as fact.
- **Prohibited behavior:** Treating difficulty as impossibility; lowering DC and applying disadvantage for the same smoke.
- **Acceptance criteria:** Smoke is recorded as the disadvantage source; lowest of two d20 results is used.

### WI-008 — Advantage and disadvantage cancel

- **Exact declaration:** `I track the hound by Lupin's fresh trail markers despite the driving rain.`
- **Relevant state:** Lupin's valid markers grant advantage; driving rain imposes disadvantage; neither has an overriding special rule.
- **Expected interpretation:** Renn attempts tracking with declared aids under adverse weather; categories `investigation`, `travel`.
- **Clarification:** No.
- **Resolution:** Normal check after cancellation.
- **Expected stakes:** Standard forward-moving tracking envelope.
- **Prohibited behavior:** Rolling three dice; stacking advantage; silently ignoring either source.
- **Acceptance criteria:** Both source arrays remain audited; displayed state is `normal`; one d20 is accepted.

### WI-009 — Valid assistance grants advantage

- **Exact declaration:** `I examine the crushed herbs while Soren compares them with her field notes.`
- **Relevant state:** Soren is present, capable, and has relevant Nature/herbalism knowledge.
- **Expected interpretation:** Renn leads examination; Soren provides a plausible bounded contribution; categories `investigation`, `assistance`.
- **Clarification:** No.
- **Resolution:** Check with advantage if uncertainty remains; public.
- **Expected stakes:** Identification progress or a proportionate ambiguity/time complication.
- **Prohibited behavior:** Soren deciding Renn's conclusion; consuming Soren's limited resource; double-counting assistance.
- **Acceptance criteria:** Helper ID and contribution are recorded; exactly one advantage source is applied.

### WI-010 — Invalid assistance does not grant advantage

- **Exact declaration:** `Lupin helps me decipher the sealed archmage notation.`
- **Relevant state:** The task requires specialized arcane literacy that neither Renn nor Lupin possesses.
- **Expected interpretation:** Renn attempts deciphering and requests assistance; Lupin is present but lacks the required capability.
- **Clarification:** No unless another declared method is materially ambiguous.
- **Resolution:** `impossible` for full deciphering, or supported partial `information` for obvious symbols; no advantage roll.
- **Expected stakes:** Explain the character-known expertise barrier and preserve any feasible observation.
- **Prohibited behavior:** Rolling because a helper exists; inventing Lupin's proficiency; presenting a fixed choice menu.
- **Acceptance criteria:** No roll for impossible full outcome; open prompt follows.

### WI-011 — Opposed check for mutually exclusive active goals

- **Exact declaration:** `I race Lupin to the fern line.`
- **Relevant state:** F-HB-01; Lupin accepts and actively races; both can reach the destination.
- **Expected interpretation:** Renn and Lupin pursue mutually exclusive first-arrival outcomes; categories `travel`, `social`.
- **Clarification:** No.
- **Resolution:** `opposed_check`; relevant movement statistic for each actor; public; ties preserve the status quo/no clear winner.
- **Expected stakes:** Determine only who arrives first and proportionate positioning consequences.
- **Prohibited behavior:** Static inflated DC merely to make Lupin hard; declaring Renn's tactics or feelings.
- **Acceptance criteria:** Both totals and modifiers are audited; no post-roll target change.

### WI-012 — Static DC instead of unnecessary opposition

- **Exact declaration:** `I try to convince the wary gatekeeper that our marked invitation is authentic.`
- **Relevant state:** Gatekeeper evaluates evidence but is not actively pursuing a mutually exclusive contest using a specific mechanic.
- **Expected interpretation:** Renn attempts persuasion through the invitation; categories `social`.
- **Clarification:** No.
- **Resolution:** `check` against a suitable fixed DC, not opposed Persuasion/Insight.
- **Expected stakes:** Access, delay, request for corroboration, or guarded reception within the locked envelope.
- **Prohibited behavior:** Opposed roll solely to increase difficulty; inventing additional promises by Renn.
- **Acceptance criteria:** DC derives from task/circumstances and is locked before roll.

### WI-013 — Creature appearance does not automatically start initiative

- **Exact declaration:** `I hold still and watch the Crown Hare.`
- **Relevant state:** Crown Hare is visible but not attacking; moment-by-moment opposed ordering does not matter.
- **Expected interpretation:** Renn attempts quiet observation; categories `exploration`.
- **Clarification:** No.
- **Resolution:** `automatic`, `information`, or a justified check; not initiative merely due to creature presence.
- **Expected stakes:** Observation and creature response remain open-ended.
- **Prohibited behavior:** Starting combat; making Renn approach or touch it.
- **Acceptance criteria:** No `encounter_started` with initiative unless new trigger evidence is established.

### WI-014 — Initiative when moment-by-moment ordering matters

- **Exact declaration:** `I dive for the falling lantern before the Gloam Hound can knock it into the dry roots.`
- **Relevant state:** F-EN-01 plus an established imminent lantern hazard; hound actively contests timing.
- **Expected interpretation:** Renn attempts an urgent intercept before an opposed actor completes its action; categories `combat`, `exploration`.
- **Clarification:** No.
- **Resolution:** `initiative`; establish awareness/surprise from prior state, then lock order.
- **Expected stakes:** Turn order determines opportunity; it does not predetermine success.
- **Prohibited behavior:** Resolving the full action before initiative; inventing surprise.
- **Acceptance criteria:** Encounter start, initiative evidence, and turn-open boundaries autosave independently.

### WI-015 — Impossible outcome receives no roll

- **Exact declaration:** `I lift the entire stone bridge with one hand.`
- **Relevant state:** No feature or magic makes this feasible.
- **Expected interpretation:** Renn attempts impossible one-handed lifting; categories `unexpected`.
- **Clarification:** No.
- **Resolution:** `impossible`; no roll.
- **Expected stakes:** Acknowledge the exact attempt, explain only the obvious physical obstacle, and leave an open prompt.
- **Prohibited behavior:** DC 30 roll; natural-20 exception; ridicule; fixed alternatives.
- **Acceptance criteria:** No dice request or state mutation beyond warranted time; declaration remains auditable.

### WI-016 — One clarification for ambiguous target

- **Exact declaration:** `I give them the potion.`
- **Relevant state:** Soren and Lupin are both present and valid recipients; target choice changes ownership.
- **Expected interpretation:** Renn attempts to transfer one potion; categories `item_use`, `social`; ambiguity contains both recipients.
- **Clarification:** Yes, exactly one: `Do you give the potion to Soren or Lupin?`
- **Resolution:** `AWAITING_CLARIFICATION`; no roll or transfer yet.
- **Expected stakes:** Ownership changes only after the answer and validated commit.
- **Prohibited behavior:** Choosing a recipient; asking multiple questions; consuming the potion.
- **Acceptance criteria:** Clarification goes only to declaring player when private; response links to original action.

### WI-017 — No clarification for decorative omission

- **Exact declaration:** `I ask Soren whether she recognizes the motes.`
- **Relevant state:** Soren is uniquely identified and conversational wording is not mechanically material.
- **Expected interpretation:** Renn communicates the stated question to Soren; categories `speech`, `social`.
- **Clarification:** No.
- **Resolution:** `automatic`; Soren may respond from her knowledge boundary.
- **Expected stakes:** Conversation advances without dictating Renn's tone beyond the declared question.
- **Prohibited behavior:** Asking for exact wording; inventing affection, suspicion, or persuasion.
- **Acceptance criteria:** Narrow paraphrase is allowed; no player-authored dialogue beyond declaration.

### WI-018 — Correction before dice supersedes safely

- **Exact declaration v1:** `I force the latch open.`
- **Correction v2:** `I stop before touching it and inspect the hinge instead.`
- **Relevant state:** Correction arrives during `CORRECTION_WINDOW`, before roll acceptance or commit.
- **Expected interpretation:** v2 is a new action version linked by `supersedes_action_id`; v1 remains immutable audit evidence.
- **Clarification:** No.
- **Resolution:** Reinterpret v2; cancel v1 before resolution.
- **Expected stakes:** Only v2 may create a ruling or consequence.
- **Prohibited behavior:** Editing v1 in place; accepting a stale v1 roll.
- **Acceptance criteria:** Old roll request is invalidated; journal contains both versions and link.

### WI-019 — Correction after roll requires compensating process

- **Exact declaration:** `I force the latch open.`
- **Later statement:** `That isn't what I meant; I wanted to inspect it.`
- **Relevant state:** Roll evidence was already durably accepted.
- **Expected interpretation:** Preserve objection and requested correction without rewriting the action.
- **Clarification:** No routine reinterpretation.
- **Resolution:** `action_dispute`; reversible provisional consequence may proceed or irreversible consequence pauses.
- **Expected stakes:** Any correction becomes a reviewed compensating transaction.
- **Prohibited behavior:** Deleting accepted roll; silently changing exact declaration or transaction.
- **Acceptance criteria:** Original history remains; correlation and correction references are durable.

### WI-020 — Private declaration remains private

- **Exact declaration:** `I quietly check whether Soren's account contradicts what I saw earlier.`
- **Relevant state:** F-HB-01 and F-PR-01; Renn privately knows an earlier observation.
- **Expected interpretation:** Renn compares private knowledge with Soren's account; categories `investigation`, `social`; visibility actor-private.
- **Clarification:** No unless the referenced account is not unique.
- **Resolution:** `information` or justified private check.
- **Expected stakes:** Actor-private comparison or uncertainty; public narration may be empty.
- **Prohibited behavior:** Shared caption/audio; public implication that Renn distrusts Soren; leaking earlier observation.
- **Acceptance criteria:** Declaration absent from shared screen, other-player payloads, shared-audio input, and unauthorized logs.

### WI-021 — Private physical roll uses neutral shared prompt

- **Exact declaration:** `I privately investigate whether the floorboards hide a pressure plate.`
- **Relevant state:** F-PR-01; uncertainty warrants a player-entered physical roll.
- **Expected interpretation:** Private investigation; actor and host receive full locked ruling.
- **Clarification:** No.
- **Resolution:** Private `check`; shared screen receives only neutral dice inputs required.
- **Expected stakes:** Private discovery or proportionate complication; public effects only after they become perceptible.
- **Prohibited behavior:** Shared declaration, actor name, skill, target, DC, stakes, or private arithmetic.
- **Acceptance criteria:** Serialized shared payload contains none of those fields; physical evidence still binds to one roll request.

### WI-022 — Host-secret roll remains sealed and auditable

- **Exact declaration:** `I listen for any sign that someone is following us.`
- **Relevant state:** F-PR-01; revealing the existence or target of the check would expose hidden information.
- **Expected interpretation:** Renn attempts alert listening; categories `investigation`; secret treatment is justified by information sensitivity, not difficulty.
- **Clarification:** No.
- **Resolution:** `check`, `host_secret`; full locked calculation host-only.
- **Expected stakes:** Renn receives only perceivable information; secrecy has an expiry/disclosure rule.
- **Prohibited behavior:** Shared roll panel; fabricated reassurance on failure; indefinite unaudited secrecy.
- **Acceptance criteria:** Full evidence exists in host journal, absent from unauthorized snapshots, and can later produce a disclosure event.

### WI-023 — Attack then damage as chained rolls

- **Exact declaration:** `I strike the Gloam Hound with my staff.`
- **Relevant state:** F-EN-01; Renn's staff attack is authoritative; target is in reach.
- **Expected interpretation:** Renn attempts a staff attack; categories `combat`; target Gloam Hound.
- **Clarification:** No.
- **Resolution:** `attack` against AC; damage roll requested only if hit is established.
- **Expected stakes:** Hit permits authoritative staff damage; miss changes positioning/tempo without damage.
- **Prohibited behavior:** Damage before hit; spending unrelated resources; critical ability-check rules.
- **Acceptance criteria:** Attack and damage have distinct locked roll IDs; HP remains bounded; one atomic outcome transaction.

### WI-024 — Saving throw then damage with resistance

- **Exact declaration:** `I brace against the hound's shadow burst.`
- **Relevant state:** An authoritative creature effect calls for a save and typed damage; Renn has an established resistance only if fixture explicitly adds one.
- **Expected interpretation:** Renn resists an involuntary effect; categories `combat`.
- **Clarification:** No.
- **Resolution:** `saving_throw`, followed by damage dice if applicable.
- **Expected stakes:** Full/half/no damage exactly as the rule states; resistance applies once after appropriate reductions.
- **Prohibited behavior:** Invented resistance; negative HP; changing damage type post-roll.
- **Acceptance criteria:** Ordered arithmetic shows save outcome, damage dice, rule reduction, resistance, and final HP delta.

### WI-025 — Healing respects maximum HP

- **Exact declaration:** `I drink my Potion of Healing.`
- **Relevant state:** F-RS-01 with Renn at 4/10 HP and exactly one potion.
- **Expected interpretation:** Renn explicitly consumes their potion for healing; categories `item_use`; resource candidate potion.
- **Clarification:** No because only one qualifying potion exists.
- **Resolution:** Automatic item activation plus authoritative non-d20 healing roll.
- **Expected stakes:** Potion is consumed once; HP increases no higher than 10.
- **Prohibited behavior:** Retaining potion; overhealing beyond maximum; applying healing before resource validation.
- **Acceptance criteria:** Healing dice evidence, inventory decrement, and bounded HP mutation commit atomically and replay idempotently.

### WI-026 — Ambiguous potion requires clarification

- **Exact declaration:** `I drink the potion.`
- **Relevant state:** Renn owns two materially different drinkable potions.
- **Expected interpretation:** Item-use intent is clear but resource identity is materially ambiguous.
- **Clarification:** Yes, exactly one question naming the valid potion identities without recommending one.
- **Resolution:** Await clarification; no resource mutation.
- **Expected stakes:** Selected potion's established effect only.
- **Prohibited behavior:** Choosing healing potion; rolling effect early; exposing private inventory publicly.
- **Acceptance criteria:** No item count changes before clarification and commit.

### WI-027 — Companion cannot spend Renn's resource

- **Exact declaration:** `Soren can decide whether to use one of my healing potions later.`
- **Relevant state:** F-RS-01; statement may propose standing permission but lacks scope, trigger, maximum spend, and expiry.
- **Expected interpretation:** Renn expresses possible delegation requiring permission configuration; categories `social`, `item_use`.
- **Clarification:** Yes if the product accepts this as a standing-permission request; ask one bounded question at a time through permission setup.
- **Resolution:** No immediate item use; create permission only after required scope is explicit.
- **Expected stakes:** Future qualifying use only within committed permission.
- **Prohibited behavior:** Immediate potion use; unlimited permanent authority inferred from casual wording.
- **Acceptance criteria:** No resource spent; permission record is explicit, revocable, and actor-authenticated.

### WI-028 — Companion may use own authorized resource

- **Exact declaration:** `Soren, use your healing magic on Lupin if you think it will keep him standing.`
- **Relevant state:** Soren has an available healing resource, Lupin is wounded, and companion autonomy permits this response.
- **Expected interpretation:** Renn requests Soren use Soren's own resource on Lupin; categories `speech`, `magic`; target Lupin.
- **Clarification:** No if spell/resource is uniquely suitable; Soren retains NPC judgment within autonomy settings.
- **Resolution:** Authoritative spell use/healing when Soren acts.
- **Expected stakes:** Soren's resource may decrement, not Renn's; healing is bounded.
- **Prohibited behavior:** Renn casting the spell; Soren spending shared/player inventory; inventing Renn's feelings.
- **Acceptance criteria:** Source character, resource owner, target, dice, and state delta are explicit.

### WI-029 — Player sovereignty: observation is not touching

- **Exact declaration:** `I study the Crown Hare from a distance.`
- **Relevant state:** F-HB-01.
- **Expected interpretation:** Renn observes while maintaining distance; categories `investigation`, `exploration`.
- **Clarification:** No.
- **Resolution:** Information or justified check; no movement/touch.
- **Expected stakes:** Observation may reveal bounded information or prompt creature reaction from existing state.
- **Prohibited behavior:** Renn approaches, reaches out, offers food, feels affection, or concludes the hare is friendly.
- **Acceptance criteria:** Generated narration contains no undeclared voluntary conduct or internal state.

### WI-030 — Player sovereignty: speech content remains bounded

- **Exact declaration:** `I tell the gatekeeper that we were invited by the herbalist.`
- **Relevant state:** Invitation claim may be true or false according to actor-known records.
- **Expected interpretation:** Renn communicates only that proposition; categories `speech`, `social`.
- **Clarification:** No.
- **Resolution:** Automatic speech followed by appropriate reaction/check if uncertainty and stakes warrant it.
- **Expected stakes:** Gatekeeper response remains state-grounded.
- **Prohibited behavior:** Adding promises, threats, names, secrets, tone, confession, or consent.
- **Acceptance criteria:** Any paraphrase is directly entailed by the declaration.

### WI-031 — Player sovereignty: no automatic limited resource

- **Exact declaration:** `I try to keep Soren safe as we cross.`
- **Relevant state:** Renn owns healing supplies and magic but names no resource and has no standing permission.
- **Expected interpretation:** Renn attempts protective positioning/care; resource candidates may be listed but not spent.
- **Clarification:** Only if materially different protective approaches must be distinguished before risk.
- **Resolution:** Automatic movement or a check based on the clarified/obvious approach.
- **Expected stakes:** Protection attempt within declared conduct.
- **Prohibited behavior:** Casting a spell, consuming potion, using healer's kit, or choosing Renn's tactics.
- **Acceptance criteria:** Inventory and spell resources remain unchanged absent explicit authorization.

### WI-032 — Natural 20 does not exceed the consequence envelope

- **Exact declaration:** `I ask the ancient sealed door to open for me.`
- **Relevant state:** Door cannot understand speech and has no established responsive magic; speaking is feasible but commanding it open this way is impossible.
- **Expected interpretation:** Renn speaks to door; desired opening is impossible by the declared method.
- **Clarification:** No.
- **Resolution:** Automatic speech plus `impossible` desired effect; no roll.
- **Expected stakes:** Door remains governed by established mechanisms; useful obvious context may be provided.
- **Prohibited behavior:** Persuasion roll; natural-20 opening; inventing sentience.
- **Acceptance criteria:** Test harness rejects any attempt to create a roll request for the impossible effect.

### WI-033 — Simultaneous compatible actions coordinate

- **Exact declarations:** Renn: `I hold the lantern toward the tracks.` Soren: `I compare the illuminated tracks with my field notes.`
- **Relevant state:** Both public submissions enter the same configured intent window.
- **Expected interpretation:** Two distinct actors perform compatible contributions; categories `exploration`, `investigation`, `assistance`.
- **Clarification:** No.
- **Resolution:** Coordinated automatic information or one justified check with eligible assistance.
- **Expected stakes:** Combined method may improve information without erasing either action.
- **Prohibited behavior:** Discarding one declaration; merging authorship; making either player control the other.
- **Acceptance criteria:** `intent_group` contains both immutable action IDs and ordering is auditable.

### WI-034 — Simultaneous conflicting actions preserve both

- **Exact declarations:** Renn: `I close the rootway gate.` Another player: `I pull the rootway gate open.`
- **Relevant state:** Same intent window; both actors can reach the gate; outcomes are mutually exclusive.
- **Expected interpretation:** Conflicting active goals; categories `exploration`.
- **Clarification:** No.
- **Resolution:** Fictional ordering, opposed check, or initiative if moment-by-moment timing matters.
- **Expected stakes:** Gate state follows the resolved conflict only.
- **Prohibited behavior:** Choosing which player “really acted”; silently dropping the private/second action.
- **Acceptance criteria:** Both actions remain durable and linked to the intent group.

### WI-035 — Private simultaneous action affects timing without leakage

- **Exact declaration:** `I privately slip the latch before anyone reaches the gate.`
- **Relevant state:** Another public action attempts to open the same gate during the intent window.
- **Expected interpretation:** Private action materially affects order; categories `exploration`.
- **Clarification:** No if target is unique.
- **Resolution:** Fictional ordering/opposed/initiative as warranted; actor-private.
- **Expected stakes:** Public clients may receive only neutral timing information if necessary.
- **Prohibited behavior:** Revealing action text, actor, latch, skill, or goal.
- **Acceptance criteria:** Public serialized payload contains at most `another action affects the timing`; host has full audit.

### WI-036 — Open-ended monster social action

- **Exact declaration:** `I lower my staff and tell the Gloam Hound that I do not want to hurt it.`
- **Relevant state:** F-EN-01; no rule forces immediate attack and the creature can perceive tone/gesture.
- **Expected interpretation:** Renn lowers their staff and communicates the stated message; categories `social`, `combat`.
- **Clarification:** No.
- **Resolution:** Automatic declared conduct plus a social check only if uncertain response and meaningful stakes exist; initiative remains if already active.
- **Expected stakes:** Creature disposition, tempo, distance, or opportunity may change within canonical capabilities.
- **Prohibited behavior:** Guaranteeing peace; adding promises; ending encounter solely because story needs it.
- **Acceptance criteria:** No fixed choice list; companions may react without deciding Renn's next action.

### WI-037 — Invalid physical die entry is correctable only before acceptance

- **Exact declaration:** Use the locked action from WI-004.
- **Relevant state:** Shared screen submits physical d20 value `27`.
- **Expected interpretation:** No gameplay reinterpretation.
- **Clarification:** No.
- **Resolution:** Reject invalid roll evidence; keep original roll request active.
- **Expected stakes:** None until a valid value is accepted.
- **Prohibited behavior:** Clamping to 20; accepting then silently editing.
- **Acceptance criteria:** Safe error has correlation ID; valid resubmission commits once; post-ack correction uses reviewed record.

### WI-038 — Duplicate action and roll are idempotent

- **Exact declaration:** `I examine the bridge hinge for recent tool marks.`
- **Relevant state:** Same `client_action_id` is sent twice; resulting same `client_roll_submission_id` is sent twice.
- **Expected interpretation:** One action and one roll request only.
- **Clarification:** No.
- **Resolution:** Appropriate information/check path.
- **Expected stakes:** Normal locked envelope.
- **Prohibited behavior:** Duplicate time, discovery, resource, narration, or transaction.
- **Acceptance criteria:** Replays return original acknowledgements and original IDs; state head advances at most once.

### WI-039 — Safety redirect preserves privacy and control

- **Exact declaration:** `Pause.`
- **Relevant state:** Any active presentation; a private safety boundary may exist.
- **Expected interpretation:** Immediate safety control, no explanation required.
- **Clarification:** No.
- **Resolution:** `PAUSED` or `SAFETY_REDIRECT` as configured.
- **Expected stakes:** Affected presentation stops; neutral acknowledgement avoids repeating content.
- **Prohibited behavior:** Asking who set the boundary; exposing private limit; continuing audio.
- **Acceptance criteria:** Stop event precedes further presentation; private source is absent from public payloads.

### WI-040 — Reduced mode remains honest and deterministic

- **Exact declaration:** `I ask whether the motes correspond to a Hemlock tradition that has not been established.`
- **Relevant state:** AI/internet unavailable; no canonical record establishes the requested new tradition.
- **Expected interpretation:** Renn requests potentially unestablished cultural information; categories `investigation`, `social`.
- **Clarification:** No unless a narrower actor-known question would materially help.
- **Resolution:** Reduced-mode bounded information response or explicit inability to establish the new fact responsibly.
- **Expected stakes:** Existing facts remain usable; play returns to an open prompt.
- **Prohibited behavior:** Fabricating tradition as canon; exposing provider failure details; blocking supported actions.
- **Acceptance criteria:** Status says `Reduced improvisation`; no invalid mutation or sealed leakage.

## 5. Cross-case invariants

Every case must also assert:

- exact declarations are immutable after durable receipt;
- visibility never broadens automatically;
- assumptions are narrow, recorded, and correctable before dice/commit;
- all DCs, ACs, opposed modifiers, advantage states, stakes, and consequence envelopes are locked before roll evidence;
- non-secret arithmetic is transparent and secret arithmetic is host-audited;
- no player-controlled limited resource is spent without explicit action or active standing permission;
- HP, resources, conditions, inventory, equipment, knowledge, and time remain within authoritative bounds;
- generated outputs are proposals until deterministic validation and Contract 1.1 commit succeed;
- public narration does not assert uncommitted canonical consequences;
- companion contributions respect knowledge, autonomy, spotlight budget, and player control;
- restart/reconnect replays the correct pending state without duplicate effects; and
- no test mutates the production campaign package.

## 6. Automation tiers

### Tier A — Pure interpreter fixtures

Run WI-001 through WI-017 and WI-029 through WI-032 as deterministic input/output schema tests with canonical fixture records.

### Tier B — WebSocket and privacy integration

Run WI-018 through WI-022, WI-033 through WI-035, and WI-037 through WI-039 using authenticated DM, shared-screen, and multiple Wayfolio clients. Inspect raw payloads.

### Tier C — Rules and transaction integration

Run WI-023 through WI-028 and WI-036 against a disposable Contract 1.1 campaign. Validate dice evidence, resource conservation, state heads, transaction hashes, and projections.

### Tier D — Recovery and fallback

Interrupt the host after every durable lifecycle boundary in representative cases WI-004, WI-018, WI-022, WI-025, and WI-038. Restart and assert correct resumption. Run WI-040 with network/provider access disabled.

## 7. Completion gate

This suite passes only when every applicable assertion succeeds in both full-improvisation and reduced-improvisation modes, all privacy cases inspect serialized data rather than UI hiding alone, and repeated submissions or restarts cannot duplicate a roll, resource expenditure, transaction, or presentation job.
