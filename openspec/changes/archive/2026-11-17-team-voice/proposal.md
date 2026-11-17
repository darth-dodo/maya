# Proposal: team-voice

## Why

Decided by Abhishek on 2026-11-16: "Provide tools to update team" and "Voice + on-screen edit". Today a Guest can add to the Team (`caught`), raise a level (`level_up`), evolve and release, but cannot say what the game shows after a trip to the PC: who is in the box, who leads, or the whole Team at once. Maya's Progress drifts from the save and her matchup advice drifts with it. This change gives voice the Team edits; `team-edit` puts the same Events on the screen.

## What Changes

- New `log_event` kinds, each one Event, undoable with the existing `undo`, validated against Maya's game data (species, levels 1 to 100, a Team of 1 to 6, the PC box holds the rest), each with one confirm or refused line:
  - `deposited`: one Team member to the PC box. Refused for the last Team member.
  - `withdrawn`: one PC box member to the Team. Refused when the Team has 6, naming one member to deposit first (the lowest level, ties to the last in Team order).
  - `set_lead`: move one Team member to the front; the rest keep their order (the `team-collapse` summary line lists names in Team order).
  - `set_team`: replace the whole Team in one Event from "My Team is Mudkip 16, Taillow 12, ...". Named members come from the Team or the PC box, or are added; members not named go to the PC box, never deleted.
  - `set_level`: set a level, down as well as up ("That Poochyena is level 9"), for a Team or PC box member.
- An optional `slot` detail (1-based position in the Team, or in the PC box for `withdrawn`) picks one of two same-species members. The screen sends it; the tool schema does not list it, to keep the schema short.
- A Team change that leaves Progress as it is writes no Event and says so ("Mudkip is already your lead."), and a `deposited` or `withdrawn` that repeats the Guest's last Event inside 2 minutes is logged once (LESSONS.md, idempotent tool writes, #86).
- `level_up` stays valid in Events for old Events and callers, but the tool's kind list offers `set_level` instead, so the model has one way to log a level.
- One system prompt line per new kind, and the honesty rule (#118) stays: never say a Team change happened unless `log_event` confirmed it.
- Spoiler probe set gains Team change cases; agent latency before and after (the tool schema grows).

Out of scope: moves, held items, nicknames, gender or shininess; more than one PC box; reordering beyond the lead; a confirm question before `set_team`. New ideas go to PHASE_2.md.

Sequencing: builds on main after #160 (live band refresh) and #162 (PC box, `released`, 2-minute repeat guard), both merged. Builds before `team-edit`, which writes these kinds from the screen.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `events`: five new kinds, the `slot` detail, a no-change rule and a wider repeat guard.
- `agent`: prompt lines for the new kinds, Team change probe cases and a latency check.

## Impact

- Code: `lib/maya/events.ex` (new `change/4` clauses, the no-change and repeat checks), `lib/maya/agent/tools.ex` (kind list and the `team` detail in the schema), `lib/maya/agent/prompt.ex` (rule 7). No migration: Events keep `kind`, `details` and `previous` as today.
- Tests: `test/maya/events_test.exs`, `test/maya/agent/*`, `test/fixtures/spoiler_probes.json` with `test/maya/spoiler_gate_test.exs`.
- Voice loop: agent stage only (more schema tokens); `mix maya.latency` before and after.
- Issue: to be filed after the spec PR (factory:plan step 6).
