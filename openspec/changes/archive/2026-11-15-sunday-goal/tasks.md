# Tasks: sunday-goal

## 1. Probe set and the spoiler gate

- [x] 1.1 Add `test/fixtures/spoiler_probes.json`: 20 Questions with their tool call (7 gym leaders Brawly to Juan, 7 gift, legendary and fossil Pokémon including Groudon and Beldum, 6 wild Pokémon found only past Rustboro), the forbidden names and the forbidden wording. Verify: `jq '.probes | length'` prints 20.
- [x] 1.2 Add a `spoiler_gate` tagged test that runs every probe through `Maya.Agent.answer/3` with OpenRouter stubbed and asserts `past_horizon` per tool result and no forbidden name in any system or tool message. Verify: `mix test --only spoiler_gate` fails on Groudon before 1.4 (the red run).
- [x] 1.3 Add the `spoiler-gate` job to `.github/workflows/ci.yml` (Postgres service, `mix test --only spoiler_gate`) and to `ci-success`'s needs. Verify: actionlint if installed; CI shows `spoiler-gate` red on the first push, failing `ci-success`.
- [x] 1.4 `find_pokemon` returns `past_horizon` for a species with no wild place inside the horizon unless on the Team, with Facts tests for Groudon, Beldum and Mudkip on the Team. Verify: `mix test test/maya/agent/facts_test.exs` and the gate pass; CI green on the second push.

- [x] 1.5 Add the honesty case from #118 to the probe file (a stubbed reply claiming a refusal with no tool call) and a check that flags a reply stating an Event or refusal when no `log_event` call ran in that turn. The agent-level assertion is a skipped test that #118 enables. Verify: the check test passes; the skipped test names #118.

## 2. Roxanne then Ralts

- [x] 2.1 Add a stubbed agent test asking the two Sunday Questions in order with the first turn as history: Nosepass ace and Mudkip lead, then Route 102, and the second request carrying the first turn. Verify: `mix test test/maya/agent_test.exs`.

## 3. Nightly real-model probe

- [x] 3.1 Add `scripts/spoiler_probe.sh`: reads the probe file, asks each Question through `POST /health/ask` with `SMOKE_TOKEN`, checks each Answer against the forbidden names (minus its own Question's words) and wording, opens one `bug` Issue per run on a leak, skips without a token, always exits 0. Verify: `scripts/spoiler_probe_test.sh` covers a leak, no leak and no token with `DRY_RUN=1`.
- [x] 3.2 Add `.github/workflows/spoiler-probe.yml`: nightly cron and `workflow_dispatch` only, `issues: write`, step `continue-on-error`. Verify: actionlint if installed; no `push` or `pull_request` trigger.
- [x] 3.3 Add the dispatch line (`gh workflow run spoiler-probe.yml`) to the `release-manager` skill. Verify: the skill names it.

## 4. Phone checklist and docs

- [x] 4.1 Add `mix maya.sunday`: prints the phone checklist (the two Questions, 10 holds, Answer time under 8 s, `mix maya.latency`) and the latency SQL from #40. Verify: a Mix task test asserts each item in the output.
- [x] 4.2 Changelog fragment, CLAUDE.md status line. Verify: `openspec validate --all --strict`, `mix precommit` and `mix credo` green.

## Workflow follow-up

- Archive with `openspec-archive-change sunday-goal` in the build PR.
- Abhishek runs the phone checklist and pastes the latency numbers on #40.
