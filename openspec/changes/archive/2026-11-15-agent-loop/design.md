# Design

## Context

See proposal.md for why. Block 2 left `Maya.Conversation` running STT, then an echo, then streamed TTS, each in a monitored Task, with stage timings sent by `Maya.Voice.Timing`. Block 1 left the game data tables, `Maya.GameData` queries and the pure `Maya.Horizon`. Progress is one row (badges, Team, location, humor).

## Goals / Non-Goals

Goals: the Roxanne Question answered from tool Facts; a testable loop with no network in tests; the agent stage timed like the others.

Non-goals: streaming the model reply into TTS, retries, more tools than `gym_counter` and `find_pokemon`.

## Decisions

- **Pure core, thin shell (ARCHITECTURE.md "Functional programming").** `Maya.Agent.Facts` holds the pure tool logic over plain data (trainer, species, matchups, locations, Progress). `Maya.Agent.Tools` is the shell: tool definitions, argument dispatch, and the queries that feed `Facts`. `Maya.Agent` is the loop; its reply classification and message building are pure functions, the HTTP call goes through Req. Alternative: one module mixing queries and logic; rejected because the horizon rules would then need the database to test.
- **Malformed arguments become a tool message.** A call whose `arguments` do not decode to a JSON object gets `{"error": "malformed_arguments"}` as its tool result, so the model can retry inside the round cap. Alternative: end the turn with the agent error line; rejected because one bad call would waste a good second round.
- **Round cap returns an error.** After 4 requests that all asked for tools, the loop returns `{:error, :round_cap}` and the Conversation speaks the agent error line.
- **Matchups use the Pokemon's types, not its moves.** Progress stores species and level only. The best multiplier of a Team member's types against the ace's types (product over the ace's types) decides the suggested lead; ties go to the higher level. Upgrade when the Team carries moves.
- **Leader names match case-insensitively** after dropping a trailing "'s" ("Roxanne's" works). Pokemon names are lowercased with spaces turned into hyphens, matching PokeAPI names.
- **`find_pokemon` and the horizon.** A species with wild places, none of them inside the horizon, is `past_horizon`. A species with no wild places at all (a starter) is a Fact with an empty place list, since nothing about a place is revealed. Encounter maps that are not in `locations` fail closed (Horizon).
- **Past-horizon hint.** The tool result carries a hint naming only the Next gym's leader, never a place, and the prompt tells the model to use it.
- **OpenRouter client mirrors Mistral.** `config :maya, :openrouter` with `base_url`, `api_key` (runtime.exs only) and `req_options` (`plug: {Req.Test, Maya.OpenRouter}` in test). The model and timeout live in `config :maya, :voice` as `agent_model` and `agent_timeout_ms`, next to the STT and TTS models.
- **Default model `anthropic/claude-haiku-5.5`**, listed with tools support on `https://openrouter.ai/api/v1/models?supported_parameters=tools` on 2026-11-14. Candidates for ADR-007: `anthropic/claude-haiku-5.5`, `google/gemini-3.8-flash`, `openai/gpt-5.4-mini`. No sampling parameters are sent.
- **Agent stage timing.** The agent Task runs inside `:telemetry.span([:maya, :voice, :agent], ...)`; `Maya.Voice.Timing` maps it to a new `turns.agent_ms` column, and `Maya.Voice.Latency` lists it, so `mix maya.latency` prints it.

## Risks / Trade-offs

- [A model ignores the "Facts only" rule] → the tools never return past-horizon data, so a model can only invent from memory; Block 4's probe set measures it.
- [A slow model blows the 5 s Answer time] → `mix maya.compare_models` and ADR-007 pick by measured agent milliseconds; `agent_timeout_ms` bounds the stage.
- [The last 5 turns plus Progress add a DB read per Question] → both are small single queries; ADR-006 asks to check the agent stage with and without them.

## Migration Plan

One migration adds a nullable `turns.agent_ms`; old rows read as missing in `mix maya.latency`. Set `OPENROUTER_API_KEY` in the Render dashboard before merging; without it every Answer is the agent error line.
