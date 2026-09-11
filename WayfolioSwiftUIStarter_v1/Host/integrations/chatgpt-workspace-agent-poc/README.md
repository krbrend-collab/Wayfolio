# ChatGPT Workspace Agent storyteller experiment

This folder is intentionally isolated from the live Wayfolio storyteller and user interfaces. It tests whether a published ChatGPT Workspace Agent can be triggered from the Mac host and return its structured result through private Wayfolio MCP tools.

## What is implemented

- Workspace Agent trigger requests with a stable `conversation_key` and `Idempotency-Key`.
- Optional beta run-status inspection. Run status is diagnostic only; OpenAI does not currently return the agent's answer through this API.
- Three MCP tools: `wayfolio_get_turn_context`, `wayfolio_publish_turn`, and `wayfolio_report_failure`.
- Validation against Wayfolio's existing `StorytellerContext` and `StorytellerTurn` contracts.
- Rejection of stale state, mismatched sessions/turns, and conflicting duplicate publications.
- Public/private delivery accounting and an immutable in-process audit log.
- A local stdio MCP process suitable for a Secure MCP Tunnel smoke test.

The `publish_turn` tool validates a proposed turn and calls an injected validation callback. It does not directly alter campaign data.

## What remains intentionally unconnected

- The production storyteller remains `OpenAIStorytellerTransport` and is unchanged.
- No iPhone, iPad, DM, launcher, audio, or visual-generation UI has changed.
- No Workspace Agent token, trigger ID, tunnel ID, or Platform runtime key is stored in the project.
- A real Business/Enterprise Workspace Agent must still be created and published by the user.
- The custom MCP tool's unattended approval behavior and ChatGPT-credit billing must be proven in the real workspace.

## Local verification

From `Host`:

```sh
npm run test:workspace-agent-poc
```

For a future Secure MCP Tunnel smoke test, point the tunnel client at this stdio command:

```sh
node integrations/chatgpt-workspace-agent-poc/mcp-stdio.mjs
```

The demo turn ID is `poc-turn-1`. The Workspace Agent should always:

1. call `wayfolio_get_turn_context` with that turn ID;
2. resolve the declaration without presenting fixed choices;
3. finish with exactly one `wayfolio_publish_turn` call, or call `wayfolio_report_failure`.

## Required real-workspace inputs

Do not place secrets in source control. The eventual launcher/runtime should read these from secure host storage:

- Workspace Agent access token
- published API trigger ID (`agtch_...`)
- Secure MCP Tunnel ID (`tunnel_...`)
- tunnel-client runtime API key

This experiment should not become the default provider until repeated end-to-end tests prove unattended MCP publication, recovery, real credit use, and multi-hour reliability.
