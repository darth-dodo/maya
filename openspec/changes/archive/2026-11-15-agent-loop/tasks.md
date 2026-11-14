# Tasks

## 1. Pure core (tests first)

- [x] 1.1 `Maya.Agent.Facts.gym_counter/…` and `find_pokemon/…` over plain data (Roxanne Fact, Brawly past horizon, not found, Ralts places, past-horizon species, starter with no places); verify red then green
- [x] 1.2 `Maya.Agent.Prompt` system prompt from Progress and the Next gym (rules, Dials, Catchphrase, no "beat" or "defeat"); verify red then green

## 2. Shell

- [ ] 2.1 Config (`:openrouter`, `agent_model`, `agent_timeout_ms`), `OPENROUTER_API_KEY` in `config/runtime.exs`, `render.yaml` (`sync: false`), FACTORY.md secrets table; verify the docker smoke test
- [ ] 2.2 `Maya.Agent.Tools` (definitions, dispatch, DB layer) with tests over imported data; verify tests
- [ ] 2.3 `Maya.Agent` loop over Req with `Req.Test` stubs (Roxanne round trip, malformed arguments, round cap, HTTP error, last 5 turns); verify tests
- [ ] 2.4 `turns.agent_ms` migration, `Timing`, `Turn` and `Latency` know the agent stage; verify `mix maya.latency` test
- [ ] 2.5 `Maya.Conversation` calls the agent with the last 5 turns inside the agent span, speaks the agent error line on failure, keeps "I did not catch that." without the agent; verify Conversation tests

## 3. Model choice

- [ ] 3.1 `mix maya.compare_models` with a stubbed test; verify the test prints one line per model
- [x] 3.2 `docs/adr/007-agent-model.md` (Proposed, candidates, empty results table) and the ADR index; verify the files

## 4. Gates

- [ ] 4.1 Run `factory:test`; verify every gate is green and the coverage floor is not lowered

## Workflow follow-up

- Archive with `openspec-archive-change agent-loop` in the same PR.
- Abhishek: set `OPENROUTER_API_KEY` on Render, run `mix maya.compare_models`, fill ADR-007, ask the Roxanne Question on the phone, paste `mix maya.latency` before and after.
