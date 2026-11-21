# Tasks: type-matchup

One build PR, size M. It says "Closes #N" and archives the change. If it passes 2x, cut the reason lines first (the tool ships with multipliers only, and `type_reasons` moves to a follow-up).

## 0. Baseline

- [ ] 0.1 Before any change: agent request size in bytes (one Roxanne request body) and `mix maya.latency` agent-stage p50 and p95 over 10 phone Questions. Verify: numbers saved for the PR body.

## 1. Reasons data

- [ ] 1.1 Pure reason checker (pair in chart with the same multiplier, no Fairy, no duplicate, at most 60 characters, no "beat" or "defeat"), with fixture tests for each problem. Verify: `mix test test/maya/game_data/`.
- [ ] 1.2 Hand-write `priv/data/type_reasons.json`: one original line per notable pair (all 0x pairs and the common 2x pairs), migration for `type_reasons`, import runs the checker before the transaction. Verify: import test and a failing fixture that changes no table.

## 2. Tool

- [ ] 2.1 `Facts.type_matchup`: defender as type, leader (ace) or Pokémon; attacker given or not; reasons joined; horizon rule. Verify: Water on Fire, Water on Geodude (4), Electric on Ground (0), Roxanne, Fairy, Wattson and Magneton at 0 badges tests.
- [ ] 2.2 Definition and `Tools.call` clause; `type_matchup` treated as a read by `Answer.check`. Verify: tools test and the write claim rejection test.

## 3. Prompt, probes, latency, docs

- [ ] 3.1 Prompt line for `type_matchup`. Verify: prompt test.
- [ ] 3.2 Probe cases at 0 and 2 badges in `test/fixtures/spoiler_probes.json`. Verify: `mix test --only spoiler_gate`.
- [ ] 3.3 Request bytes and agent-stage p50 and p95 after, next to 0.1, in the PR body. Verify: numbers in the PR.
- [ ] 3.4 ADR-004 tool list, ARCHITECTURE.md 3, changelog fragment. Verify: `openspec validate --all --strict`, `mix precommit` and `mix credo` green.
