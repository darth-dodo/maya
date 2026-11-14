# Proposal

GitHub Issue: #39

## Why

The voice spine (#38) speaks the Question back as an echo. Maya's one job is to answer it: "How do I earn Roxanne's badge?" must come back as 2 to 3 spoken sentences built only from Facts in Maya's own data, inside the Spoiler horizon (ADR-004).

## What Changes

- A hand-written agent loop over OpenRouter chat completions: `tools` on every request, each `tool_calls[].function.arguments` JSON string parsed per call (malformed is a tool error the model sees, not a crash), one `role: "tool"` message per call with its `tool_call_id`, at most 4 rounds.
- Two tools: `gym_counter(leader)` (the leader's team and levels, the player's Team with Gen 3 type matchups, a suggested lead) and `find_pokemon(name)` (types, evolutions, wild encounter places inside the horizon). Each returns a Fact, not found, or past the horizon; the Spoiler horizon is applied before anything reaches the model.
- A system prompt with the rules: Facts only from this turn's tool results, never past the Spoiler horizon ("Further ahead, no spoilers" plus a hint, naming no place), "Not sure" when there is no Fact, 2 to 3 spoken sentences, the Dials, the Catchphrase, inclusive language.
- The Conversation replaces the echo with the agent, gives it the last 5 turns, times the agent stage and stores `agent_ms` on the turn. An agent failure is one short spoken line, never silence.
- `mix maya.compare_models` runs the Roxanne Question through 2 or 3 tool-capable models and prints the agent-stage milliseconds and the Answer. ADR-007 "Agent model" records the candidates as Proposed; Abhishek fills in the numbers.
- Config: `:agent_model` and the agent timeout in config; `OPENROUTER_API_KEY` read only in `config/runtime.exs` and listed in `render.yaml`.

Out of scope: `search_guide`, `log_event`, `set_setting` (Block 5), streaming the agent reply, the spoiler probe set (Block 4). New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities
- `agent`: the agent loop, its tools, and the rules every Answer follows.

### Modified Capabilities
- `voice-loop`: the Answer comes from the agent instead of an echo; the agent stage is timed per turn; an agent failure is spoken.

## Impact

- New: `lib/maya/agent.ex`, `lib/maya/agent/*.ex`, `lib/mix/tasks/maya.compare_models.ex`, a migration adding `turns.agent_ms`, `docs/adr/007-agent-model.md`, tests.
- Changed: `lib/maya/conversation.ex`, `lib/maya/voice/{timing,turn,latency}.ex`, `config/{config,test,runtime}.exs`, `render.yaml`, `FACTORY.md` secrets table, `docs/adr/README.md`.
- No new dependencies (Req and Jason are already in the app); the CSP is unchanged.
