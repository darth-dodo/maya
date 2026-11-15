# Proposal: sunday-goal

## Why

PRODUCT.md "Done when (Sunday)" needs Zero Spoilers shown by a gate that can fail, not hoped for: nothing past Rustboro in the Roxanne and Ralts Answers or in a 20-question spoiler probe set. Today no CI job asks those questions, and #55's review found a real gap: `find_pokemon` hands the model the types of a gift or legendary Pokémon with no wild places (Groudon, Beldum), which is a Spoiler. Issue #40, Abhishek's decisions of 2026-11-15.

## What Changes

- **Probe set as data**: `test/fixtures/spoiler_probes.json` holds 20 Questions for 0 badges and a Mudkip Team (7 gym leaders past Roxanne, 7 gift, legendary and fossil Pokémon, 6 wild Pokémon found only past Rustboro), each with the tool call a model would make, plus one forbidden list: gym leaders, badges, cities, routes and places past Rustboro, and the probed Pokémon. One honesty case (#118) holds a stubbed reply that claims a refusal with no tool call; a check flags any reply stating an Event or refusal no tool returned in that turn, and its agent-level assertion stays skipped until #118 fixes the loop. A separate forbidden wording list (the words a non-inclusive Answer would use) is used only to check Answers, never as Maya copy.
- **Spoiler gate**: an ExUnit test tagged `spoiler_gate` runs every probe through `Maya.Agent.answer/3` with OpenRouter stubbed (`Req.Test`, no network): every probe's tool result is `past_horizon`, and no forbidden name appears in any system or tool message sent to the model. A new CI job `spoiler-gate` runs only that tag and is added to `ci-success`'s needs, so a leak fails the build. Shown to fail once in CI before it goes green.
- **Fix the leak the gate finds**: `find_pokemon` returns `past_horizon` for a species with no wild place inside the horizon unless it is on the player's Team (a starter the player owns stays a Fact).
- **Real-model probe**: `.github/workflows/spoiler-probe.yml`, nightly and on `workflow_dispatch`, never on push or pull request, runs `scripts/spoiler_probe.sh`: the same 20 Questions through `POST /health/ask` with `SMOKE_TOKEN`, each Answer checked against the forbidden list (minus names in its own Question) and the forbidden wording. On a leak it opens one `bug` Issue per run; it always exits 0. `release-manager` dispatches it after a release.
- **Roxanne then Ralts**: a stubbed end-to-end agent test asks both Questions in one Conversation: Roxanne's ace Nosepass and a Team counter in the first tool result, Ralts on Route 102 in the second, and the first turn in the second request's history.
- **Phone checklist**: `mix maya.sunday` prints what Abhishek runs on the phone (the two Questions, 10 holds, Answer time) and the latency SQL from #40, plus `mix maya.latency`.

Out of scope: new features, prompt rewording beyond what a failing probe needs, probes for other badge counts. New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent`: `find_pokemon` treats a species with no wild place inside the horizon as `past_horizon` unless it is on the Team; the Roxanne then Ralts Questions in one Conversation are specified.
- `delivery-pipeline`: `ci-success` also needs `spoiler-gate`; new requirements for the spoiler gate and the scheduled real-model spoiler probe.

## Impact

- Code: `lib/maya/agent/facts.ex` (`find_pokemon/4`), tests under `test/maya/`, `test/fixtures/spoiler_probes.json`, `lib/mix/tasks/maya.sunday.ex`.
- CI: `.github/workflows/ci.yml` (new job), new `.github/workflows/spoiler-probe.yml`, new `scripts/spoiler_probe.sh` with a `scripts/spoiler_probe_test.sh` like the smoke check's.
- Docs: `release-manager` skill (one dispatch line).
- Cost: 20 OpenRouter Questions a night. No new dependency, service or model.
- Issue: #40.
