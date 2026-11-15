# Design: sunday-goal

## Context

See proposal.md, Why. The agent already applies the horizon in `Maya.Agent.Facts` before a result reaches the model (ADR-004), and agent tests stub OpenRouter with `Req.Test` against game data imported into the test database. `POST /health/ask` (#55) answers one text Question for the `smoke` guest. The scheduled smoke check (post-deploy.yml) shows the house pattern for a check that opens a `bug` Issue and always exits 0.

## Goals / Non-Goals

**Goals:** one probe data file read by both the CI gate and the nightly probe; a gate that fails on a leak; the leak #55 found fixed at the tool layer.

**Non-Goals:** probing other badge counts; judging Answer quality beyond forbidden names and wording; any change to the prompt unless a probe fails on it.

## Decisions

- **Probe data in `test/fixtures/spoiler_probes.json`.** JSON so the ExUnit gate (Jason) and the bash probe (jq) read the same file. Alternative: an Elixir module, which bash cannot read. It stays out of `priv/` so the release does not ship it.
- **Forbidden names are words, matched case-insensitive on word boundaries.** "Route 11" must not match "Route 110", and a probe's own Question words are removed from the list for that probe in the real-model check, since repeating "Groudon" back in "Further ahead" is not a Spoiler. In the stubbed gate only system and tool messages are checked: the user message is the player's own words.
- **Gate job runs `mix test --only spoiler_gate` with the Postgres service.** The tool layer reads game data from Postgres, and the service container is local to the job, so the job makes no network call outside itself (the model is stubbed). The main `test` job still runs the tagged test too, so coverage does not move. Alternative: pure fixtures without the database, which would test a copy of the data, not the imported tables.
- **`find_pokemon` rule: no place inside the horizon and not on the Team is `past_horizon`.** One condition covers both the old case (places only past the horizon) and gifts, legendaries and fossils. Alternative: a hand-kept gift and legendary list, which would drift from the data. A starter the player does not own (Torchic) also becomes `past_horizon`: fail closed, matching the horizon's rule for unknown locations.
- **Real-model probe is its own workflow and script.** Nightly cron plus `workflow_dispatch`, `continue-on-error` on the step and `exit 0` in the script (LESSONS.md: scheduled checks never on push, checks exit 0). One Issue per run, titled with the run date, lists every leaking Question and Answer. `scripts/spoiler_probe_test.sh` feeds canned Answers through a `PROBE_ANSWERS` file and `DRY_RUN=1`, like `smoke_check_test.sh`.
- **Phone checklist as `mix maya.sunday`.** One command prints the steps and the latency SQL next to the code, so Abhishek does not hunt for a doc on Sunday; `mix maya.latency` already prints the numbers. Alternative: a doc under `docs/`, which drifts from the SQL the task tests.

## Risks / Trade-offs

- [The nightly probe spends OpenRouter credit, 20 Questions a night] → Abhishek decided it on 2026-11-15; dispatch is manual otherwise.
- [A real Answer can paraphrase a Spoiler without a forbidden name] → The gate shows the tool layer never hands the model one; the nightly probe catches the named ones.
- [Showing the gate fails breaks E1's push once] → The first push carries the gate before the fix, so CI shows it red; the fix is the second push. Documented in the PR as the exception LESSONS.md asks for.

## Migration Plan

None. Rollback is reverting the PR; the nightly workflow can be disabled from the Actions tab.
