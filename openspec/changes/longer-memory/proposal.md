# Proposal: longer-memory

## Why

Maya forgets fast: the agent sees only the last 5 turns, so a Question that points back further ("the one I caught earlier") gets "Not sure". Abhishek asked on 2026-11-21: "make maya remember 50 messages". Stored turns already persist in Postgres per Guest; only the window sent to the agent is short. Sending 5 times more history costs prompt tokens on every round, so the stable front of each request is cached through OpenRouter.

## What Changes

- **History**: the agent gets the last 25 turns (50 messages) instead of 5. The Conversation keeps and reloads at least 25 turns (today it keeps 20 in memory and reloads 20, `Turn.recent/2` and `conversation.ex`).
- **Prompt caching**: for `anthropic/` models, each agent request carries OpenRouter's top-level `cache_control: {"type": "ephemeral"}`, so the tools, system prompt and older history are read from cache on later rounds and turns. Other providers cache automatically and get no extra field. Source: https://openrouter.ai/docs/guides/best-practices/prompt-caching.
- **Request order stays stable**: tools, then system prompt, then history, then the Question, so each request starts with the previous one while Progress is unchanged.
- **Turn log line**: one info line per answered Question with rounds used, history turns sent, prompt tokens and cached tokens. No Question, Answer or tool content.
- **Latency**: agent-stage p50 and p95 before and after, measured by Abhishek on his phone or with `mix maya.latency`, are part of the build's Done when.

Size: S (one build PR).

Out of scope, each a separate later change with one PHASE_2.md line: the running journal (a summary per Guest) and embeddings recall over old turns. Also out: moving Progress out of the system prompt to cache more, and a 1 hour cache TTL.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent`: 25 turns as context, prompt caching, the turn log line, latency.
- `voice-loop`: the Spoken Answer requirement says 25 turns.

## Impact

- Code: `lib/maya/agent.ex` (`@history`, request body, usage read, log line), `lib/maya/voice/turn.ex`, `lib/maya/conversation.ex`, tests.
- Docs: PRODUCT.md "Answers", ARCHITECTURE.md 3 and the Conversation section.
- Voice loop: larger prompts on every agent request; caching should offset part of it. Measured before and after.
- Cost: cache writes are 1.25x and reads 0.1x the input price (OpenRouter docs).
- Issue: to be filed after this spec PR (factory:plan step 6).
