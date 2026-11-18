# Tasks: team-voice

Two build PRs (3h in all, so split): A is Events (2h), B is the agent wiring and evidence (1h). Both on main after #160 and #162 (merged). B archives the change.

## 1. Events (PR A, 2h)

- [ ] 1.1 Record the "before" agent latency: `mix maya.latency` over 10 phone Questions on main before any code change. Verify: p50 and p95 noted in PR A's body.
- [x] 1.2 `deposited` and `withdrawn` clauses in `Maya.Events.change/4`, with the full Team refusal naming the lowest level member. Verify: `test/maya/events_test.exs` tests for "Deposit", "The last Team member", "Not on the Team", "Withdraw", "Withdraw with a full Team", "Not in the PC box".
- [x] 1.3 `set_lead` and `set_level` clauses. Verify: tests for "New lead", "In the PC box" (both requirements), "A lower level", "Neither", "Level out of range" with `set_level`.
- [x] 1.4 `set_team` clause (take from Team then PC box, unnamed members to the end of the PC box, 1 to 6, level kept or required). Verify: tests for "My Team is", "Undo a whole Team", "A new species with no level", "Too many or none", "Unknown species" with `set_team`.
- [x] 1.5 `slot` detail on `deposited`, `set_lead`, `set_level`, `released`, `withdrawn`. Verify: tests for "The second Poochyena" and "A stale slot".
- [x] 1.6 No-change rule and the widened repeat guard in `run/3` (last Event, same kind and species, inside 2 minutes, for `deposited` and `withdrawn`). Verify: tests for "Already the lead", "The same Team again", "The same deposit twice", "A deposit after an undo"; existing repeat and undo tests pass unchanged.

## 2. Agent wiring and evidence (PR B, 1h)

- [x] 2.1 Tool schema: kind enum `Events.kinds() -- ["level_up"]`, one line per new kind in the `details` description, a `team` array of `{species, level}`; no `slot`. Verify: test for "The tool offers set_level, not level_up".
- [x] 2.2 Prompt rule 7: one line per new kind and the honesty line. Verify: tests for "Prompt asks for log_event", "My Team is Mudkip 16, Taillow 12", "Gym counter after a new lead".
- [ ] 2.3 Probe and honesty cases in `test/fixtures/spoiler_probes.json`. Verify: `mix test test/maya/spoiler_gate_test.exs` for "Team probes pass the spoiler gate" and "A claimed Team change without a tool call is flagged"; `scripts/spoiler_probe.sh` against the real model passes.
- [ ] 2.4 "After" latency on the phone. Verify: PR B lists agent-stage p50 and p95 before (1.1) and after, and Answer time p95 at most 8 s.
- [ ] 2.5 Phone check: "My Team is ...", "Put Wingull in the PC", "Take Lotad out", "Lead with Wingull", "That Poochyena is level 9", then "undo that", each heard and shown on the trainer card. Verify: `Phone check:` line in PR B.

## 3. Docs

- [x] 3.1 Changelog fragment per PR; GLOSSARY.md "Event" lists the Team changes if wording changed. Verify: `openspec validate --all --strict`, `mix precommit` and `mix credo` green.

## Workflow follow-up

- Archive with `openspec-archive-change team-voice` in PR B.
