# Wayfolio Shared Table Runtime Bridge — V1

Status: IMPLEMENTATION CONTRACT — READY FOR HOST + NATIVE CLIENT INTEGRATION
Date: 2026-09-01
Applies to: Mac/DM Host, Wayfolio Campaign Ledger, native Shared iPad client, personal iPhone clients where explicitly noted

## 1. Purpose

Resolve the current split between authoritative Host/Campaign state and native Xcode presentation by establishing one runtime boundary. The Mac/DM Host is the authority for party membership, reveal state, playability, assignment, Wayfolio binding, scene presence, audience filtering, and Campaign Ledger revision. Native clients render audience-specific projections; they do not independently decide campaign truth.

This contract implements the boundary required by WF-049, WF-054, WF-055, and WF-056. It does not merge `feature/ipad-login-v03` into `main` and does not waive Xcode/iPad validation.

## 2. Authority Rule

**Campaign Ledger + Mac Host runtime → audience projection → native client.**

The Host must evaluate canonical state before serialization. A secret, unrevealed, pending-introduction, or otherwise ineligible character is omitted from the shared-iPad payload entirely. The client must never receive a complete private record and merely hide it in SwiftUI.

The native Shared iPad must not become a second implementation of recruitment/reveal/playability rules. The seven independent campaign fields remain authoritative on the Host/Ledger side:

- recruitmentState
- partyMembership
- revealState
- playability
- playerAssignment
- wayfolioBinding
- scenePresence

They may be represented in private DM diagnostics, but the public iPad projection should contain only the minimum presentation-safe information required to render the shared experience.

## 3. Public Login Projection

Recommended provider-neutral Host route:

`GET /api/v1/shared/login-projection`

The exact HTTP framework may differ, but the semantic response must be preserved.

```json
{
  "protocolVersion": "wayfolio.shared-projection.v1",
  "journeyId": "stable-journey-id",
  "stateRevision": 42,
  "projectionRevision": 17,
  "generatedAt": "2026-09-01T21:00:00Z",
  "background": {
    "assetId": "stable-approved-asset-id",
    "variant": "login"
  },
  "party": [
    {
      "canonicalCharacterId": "character-id",
      "displayName": "Renn Hazel",
      "spriteSetVersion": 4,
      "sprites": [
        {
          "spriteId": "login-03",
          "assetId": "stable-approved-sprite-asset-id",
          "approvalStatus": "APPROVED",
          "loginEligible": true,
          "mirrorAllowed": true,
          "preferredFacing": "neutral",
          "minDisplayScale": 0.62,
          "maxDisplayScale": 0.86,
          "foregroundEligible": true,
          "rearSlotEligible": true
        }
      ]
    }
  ]
}
```

### Host eligibility requirement

Before a character can appear in `party`, the Host must have already established that the character is public for this projection under the current authoritative state. At minimum this includes the approved party-membership and reveal rules from WF-049/WF-056. `pendingIntroduction` and `unrevealed` characters are omitted. Temporary scene absence does not by itself remove an otherwise introduced active party member from the general login composition when campaign rules allow that member to remain part of the active party login presentation.

### Data minimization

Do not send recruitment opportunity, refusal state, private assignment details, private Wayfolio binding details, hidden scene-presence information, GM notes, unrevealed names, secret portraits, hidden sprite variants, or other DM-only fields to the shared iPad simply because the Swift model can represent them.

## 4. Native Shared iPad Responsibility

The native app should replace its hard-coded `SharedLoginCampaignContext(backgroundAssetName: nil, publicParty: [])` with a runtime projection store fed by the Host.

The native client is responsible for:

- loading the latest audience-filtered login projection;
- rejecting malformed or unsupported protocol versions;
- ignoring stale projection revisions;
- rendering only the members actually present in the Host projection;
- selecting one eligible login sprite per member for the current login session and holding that choice stable across incidental redraws;
- enforcing asset-safety metadata such as APPROVED + loginEligible and mirrorAllowed as a defensive presentation check;
- never manufacturing a party member, placeholder identity, reveal transition, or campaign state when the Host does not provide it;
- showing a non-spoiling connection state when the Host projection is unavailable.

The native client must **not** infer party membership, reveal state, playability, assignment, or Wayfolio binding from cached art or local UI state.

## 5. State Revision / Freshness

Every projection carries the Campaign Ledger `stateRevision` and a projection-specific monotonically increasing `projectionRevision` (or equivalent revision token).

Rules:

- A client may render a newer projection over an older one.
- A client must not replace a newer projection with a stale response.
- Reconnect begins by requesting a fresh authoritative projection.
- If the Host detects an invalid/stale mutation request, it follows the existing state-version repair rules rather than last-write-wins.
- Login projection reads are presentation reads and do not themselves increment Campaign Ledger state.

## 6. Real-Time Updates

After the first successful projection fetch, the Host may update native clients through the existing transport architecture using WebSocket, SSE, long polling, or another already-supported channel. Transport choice is implementation detail; the semantic event should be equivalent to:

```json
{
  "eventType": "shared.projection.updated",
  "journeyId": "stable-journey-id",
  "stateRevision": 43,
  "projectionRevision": 18
}
```

The client then fetches/applies the corresponding audience-safe projection or consumes an equivalent fully filtered projection event.

Retries/reconnects must preserve idempotency and must not duplicate introductions, assignments, account creation, knowledge grants, or other committed campaign events.

## 7. Authentication Boundary

Production account authentication remains a separate service concern from party/reveal eligibility.

Provider-neutral operations required by the native login flow:

- authenticate player credentials;
- securely persist/refresh an authenticated session when Remember Me is enabled;
- password recovery;
- create human player account;
- enumerate only canonical characters marked available for that authenticated player to claim when applicable;
- submit character import/create data as provisional until review;
- DM approval;
- player assignment;
- Wayfolio pairing.

The shared iPad login screen must not declare authentication successful based only on local text-field validation. Passwords are never stored in plaintext.

## 8. Account / Character Transaction Rule

Create Account creates a human player record only. Character progression remains separate:

1. create/authenticate player account;
2. Bring My Character / Create a Character / Play Existing Campaign Character;
3. provisional normalization/import where applicable;
4. player review;
5. DM approval where required;
6. canonical assignment;
7. Wayfolio pairing.

Existing campaign characters reuse the canonical character ID. No duplicate record is created when an NPC/companion later becomes playable.

If assignment succeeds but pairing fails, preserve assigned + pairingPending rather than rolling the character back into an ambiguous state.

## 9. Sprite Runtime Resolver Boundary

The public projection identifies approved sprite assets by stable asset ID and sprite-set version rather than relying on a bundled filename as campaign authority.

The native asset resolver should:

1. request the newest complete APPROVED set;
2. verify the set is complete before promotion;
3. cache it locally;
4. atomically switch from the previous approved set to the new complete approved set;
5. keep the last-known-good approved set;
6. fall back to last-known-good if the newest set fails;
7. expose detailed errors only to private DM diagnostics;
8. never substitute an unrelated character or unrevealed placeholder on a player-facing surface.

Ordinary approved sprite updates become ASSET UPDATE — SYNC ONLY once this resolver is implemented and validated.

## 10. Host Diagnostics

Private DM diagnostics should expose at least:

- current Campaign Ledger state revision;
- public projection revision;
- each canonical character's party/reveal/playability/assignment/binding state;
- whether the character is eligible for public login projection;
- current approved sprite-set version;
- newest available approved sprite-set version;
- cache/sync status;
- missing login-eligible pose/metadata warnings;
- last successful native projection sync.

No unrevealed character identity or private diagnostic content is mirrored onto the shared iPad.

## 11. Migration Rule

The live Campaign Ledger PARTY schema must migrate to the independent WF-049 fields without inventing missing state.

- Preserve existing canonical IDs.
- Map only values that are already established by authoritative runtime/canon.
- Unknown values remain null/unknown until legitimately established.
- Migration is journaled/revision-aware where it changes durable state.
- Do not infer player assignment, recruitment consent, reveal, pairing, or playability from art presence, folder names, historical mockups, or old UI state.

## 12. Acceptance Tests

This bridge is complete only when all of the following pass:

1. The Host has an introduced active party member and the native login receives/renders that member.
2. A pendingIntroduction/unrevealed character is absent from the network payload, not merely hidden in SwiftUI.
3. A temporarily absent but still active/introduced party member follows the approved login policy without being incorrectly removed solely by scene absence.
4. A DM introduction updates the Host state and causes exactly one public projection transition after commit.
5. Reconnect obtains the newest projection without duplicating introductions or other events.
6. Stale projection responses cannot overwrite newer client state.
7. Sprite resolver uses a complete approved set, falls back to last-known-good on failure, and does not mix versions.
8. Private DM diagnostics can identify missing/old assets without revealing them publicly.
9. Login authentication is server-authoritative rather than local-field validation.
10. Character import/create → review → approval → assignment → pairing preserves one canonical character ID.
11. Shared iPad receives no DM-only/unrevealed character data in inspected network payloads.
12. The feature branch builds in Xcode and launches in the iPad Simulator/device before merge.

## 13. Merge Gate

Do not merge `feature/ipad-login-v03` into `main` until:

- Host projection endpoint/service is implemented against the authoritative runtime;
- the native client consumes that projection instead of a hard-coded empty context;
- Xcode Product → Build succeeds;
- iPad Simulator/device launch succeeds;
- spoiler/audience payload inspection passes;
- reconnect/idempotency tests pass.

Until then the feature branch remains the integration branch.
