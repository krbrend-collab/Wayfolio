# Wayfolio Central Host

## Drive-authoritative visual assets (WF-082)

Production visuals are resolved by semantic identity through the Mac Host. The current **Wayfolio Visual Asset Manifest** in Drive is the lifecycle authority; `public/assets/approved` and the native Xcode asset bundle are bootstrap/fallback material only.

The Host refreshes the `ASSETS` sheet, filters for approved/current records that are valid for the requesting audience and knowledge scope, downloads approved bytes, validates them, and stores them atomically in `Host/data/asset-cache`. Player devices receive only an opaque Host URL. They never receive Drive credentials or Drive storage references. Content URLs include the stable asset identity, asset version, and manifest revision and are safe for long-lived device caching.

If Drive or an approved asset is temporarily unavailable, the Host reuses an eligible last-known-good cache entry or returns the neutral Luminous Ledger fallback. Gameplay continues in either case. An in-review or locally newer file is never substituted.

The default manifest is the live Visual Asset Manifest. Optional Host-only configuration:

- `WAYFOLIO_ASSET_MANIFEST_URL`: alternate authorized JSON/CSV manifest endpoint.
- `WAYFOLIO_DRIVE_ACCESS_TOKEN`: authenticated Google Sheets/Drive access when the source is private.

Host-only diagnostics are available at `/api/assets/status`. Semantic clients use `/api/assets/resolve`; cached bytes are served by opaque `/api/assets/content/...` URLs.

Run the F41 acceptance fixture with `npm run test:f41`.

### Shared-iPad login portrait cutover (WF-092–WF-093)

The public `/api/shared-login-context` projection resolves the current party's `LOGIN_PORTRAIT` assets through the same Drive-authoritative Host resolver. It returns only introduced party members, never exposes Drive identifiers or private asset diagnostics, and falls back to an approved bootstrap reference without blocking play. Its version-2 readiness projection also supplies the story checkpoint, session information, current location, five non-presentational readiness states, and the final Begin Session gate required by the Spiritbloom pre-session surface.

The current approved shared-iPad login composition is `wayfolio_ipad_login_v02.png` and must be resolved through the manifest. The bundled v01 composition is superseded and is not a production fallback. Until v02 resolves, the native app presents a neutral Luminous Ledger bootstrap surface without blocking connection recovery. The iPad composition is not authority for a personal-iPhone login.

### Personal-iPhone login approval (WF-099)

Personal iPhone Wayfolio Login V1 is separately approved through `wayfolio_iphone_login_window_v01_APPROVED.png` in Drive folder `1evDI57HgFTfw1e3n8E1LPWVl7UFxvmsC`. It uses Spiritbloom: Awakening as the top brand, `WAYFOLIO DEVICE LOGIN` as the functional label, and live code-rendered profile, device, DM connection, synchronization, checkpoint, location, readiness, error, and Begin Session state. The image is a visual shell/reference and never owns dynamic state or interaction. There is no password-based login UI. The native iPhone composition is implemented; it obtains approved login portraits and campaign state from the Host manifest-backed login context, while the composition artwork remains reference-only until it has an approved-current Visual Asset Manifest row.

## Current sync additions (WF-094–WF-099)

- Semantic audio remains contract-driven. Runtime code uses semantic trigger IDs and routing policy rather than direct filenames. Canonical master bytes and license evidence must be validated before the audio pull request is merged; missing masters do not authorize substitute sounds.
- The Wayfolio campaign package, not a ChatGPT transcript, owns story continuity. Thread health, safe rollover, generation leases, visibility slices, idempotent replay, and recovery must satisfy acceptance fixtures F42–F49 before automatic storyteller-thread replacement is considered complete.
- Every equippable item now requires a `quality_level` from 1 through 5. Exact progression curves remain configurable and must not be invented during UI work. Use the equipment family name `Protective Gear`, not generic `Armor`.

## Authenticated storyteller transport (WF-010)

Wayfolio's supported live storyteller connection uses an OpenAI Platform API key on the private Mac host and the OpenAI Responses API. The credential is stored only in the host's private `~/.wayfolio/ai-config.json` file (or supplied through `OPENAI_API_KEY`); it is never included in iPad, iPhone, or shared-screen state.

OpenAI's public application API does not provide a supported way for this localhost game host to sign into a personal ChatGPT account, attach an existing ChatGPT conversation, or inherit ChatGPT Memory. ChatGPT subscription access and OpenAI API billing are separate. Wayfolio therefore preserves story continuity in its own authoritative campaign state and sends a current `SessionResumeContext` with live storyteller work. A different valid API credential can take over without needing the former chat's private memory.

Connection changes are host-only. Replacement credentials are verified before cutover; failed replacements keep the working connection. Disconnecting removes the saved credential without deleting campaign state. Pending and completed storyteller requests are guarded by stable turn and idempotency identifiers so retries cannot duplicate committed narration or game events.

### Low-cost gameplay mode

The live storyteller now routes ordinary exploration, dialogue, information, and out-of-game DM questions to `gpt-5.6-luna`. It reserves `gpt-5.6-terra` for active combat, saving throws, opposed checks, and initiative. Dice, rules interpretation, inventory, damage, healing, audio, campaign commits, and autosaves remain local and do not create model calls.

The private Mac launcher shows measured Responses API token usage and estimated session cost. The default session cap is `$1.00`; it can be changed or reset from **AI storyteller setup** without changing campaign state. Each request reserves a conservative maximum before it is sent. When the cap cannot accommodate the next request, Wayfolio does not call the provider and continues through its state-grounded fallback.

Environment overrides are available for managed setups:

- `WAYFOLIO_AI_SESSION_BUDGET_USD`
- `WAYFOLIO_ROUTINE_STORYTELLER_MODEL`
- `WAYFOLIO_COMPLEX_STORYTELLER_MODEL`

Prompt caching uses a stable per-journey cache key. Completed idempotent replays reuse the saved provider result and never add a second charge to the Wayfolio cost ledger.

This is the first local-network multiplayer slice. The host owns the session,
the shared screen shows public information, and each phone joins as a Wayfolio.

The host binds to `Campaigns/HemlockDevelopment` at startup, validates its
Contract 1.1 manifest, and refuses to start if the formal campaign authority is
invalid. A DM-approved open-play consequence is committed to that campaign
package before the shared screen or Wayfolios are told that the turn succeeded.
The JSON file in `Host/data` remains a session/UI cache rather than campaign
authority.

1. Run `npm install` once in this folder.
2. Run `npm start`.
3. Open `http://localhost:8787/dm` for private DM controls.
4. On the host launcher, scan the shared-iPad QR code or enter the displayed network address ending in `/shared` in iPad Safari. `localhost` works only on the host Mac.
5. Keep `http://localhost:8787/launcher` available to reopen either screen during play.

For normal use, double-click `Start Wayfolio Game.command` in the starter
folder. It starts the host when needed and opens the launcher. Keep its Terminal
window open while playing. If that window is closed, double-click the launcher
again; saved campaign state is retained. On each phone, open the hare profile
button, choose **Session**, select the character, and join with the Mac's local
IP and code `HEMLOCK`.

On the shared screen, select **Enable audio** once; browsers require a player
gesture before sound can begin. The private DM page can then control shared
ambience, music, world effects, creature sounds, dialogue, and emergency stop.
Public audio never broadcasts to player Wayfolios. Reconnecting shared screens
restore current ambience and music without replaying old one-shot effects.

The host consumes the canonical files in `Specifications/Audio` and serves the
bundled assets from `Wayfolio/Resources/Audio`; do not maintain duplicate copies.

Do not put the private DM page on the shared display. Until authenticated DM
Wayfolio access is implemented, the launcher, story review, and DM browser pages
are available only on the host laptop. Private player responses are sent from an
individual Wayfolio, never from the shared screen.

For the shortest game-night sequence, see `GAME_NIGHT_CHECKLIST.md` in the
starter folder.

Formal campaign history cannot be silently undone. Corrections must be recorded
as reviewed compensating transactions so the original turn remains auditable.

## AI Storyteller runtime contract

The host implements `wayfolio.storyteller.v1` in `storyteller-runtime.mjs`.
Each open-play turn receives a compact authoritative `StorytellerContext`, and
the matching `StorytellerTurn` plus `CommitReceipt` is recorded with the formal
campaign transaction. The protocol provides state-version checks, idempotent
turn replay, two-phase mechanical resolution, temporary-to-stable entity IDs,
explicit visibility scopes, player-filtered delivery, durable continuity, and
stale-state repair. The rules interpreter and state-grounded narrator remain
the offline/provider-failure fallback; they do not claim to provide equivalent
open-ended AI storytelling when no provider is configured.

## Shared campaign knowledge

The host initializes a durable Knowledge Vault from
`Host/content/hemlock-knowledge.json`. Every AI adjudication receives a
privacy-filtered, declaration-relevant context bundle from this vault, and each
Contract 1.1 committed turn is added back as approved campaign history.

Connector-ready, host-only endpoints are available at:

- `POST /api/knowledge/context` to retrieve bounded approved context.
- `POST /api/knowledge/propose` to stage a ChatGPT or authoring update.
- `POST /api/knowledge/review` to approve or reject a staged update.

Proposals never enter model context until the private host approves them. These
local endpoints are deliberately loopback-only; a future remote ChatGPT MCP
connector must add authenticated transport rather than exposing the private host.
