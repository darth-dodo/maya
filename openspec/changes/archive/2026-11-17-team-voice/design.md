# Design: team-voice

## Context

`Maya.Events.change/4` is pure (Progress, kind, details, lookups) and returns `{:ok, progress, confirm}` or `{:refused, line}`; `log/3` locks the Progress row, writes one Event with the `previous` snapshot (badges, Team, PC box, location) and the new Progress in one transaction. `undo` restores that snapshot, so any kind that only changes Team and box is undoable for free. The tool's kind enum is `Events.kinds()`.

## Decisions

- **New `change/4` clauses, no new module.** Each kind is one clause over `progress.team` and `progress.box`, reusing `species/2`, `level/1` and `say/1`. Alternative, a `Maya.Team` module: more files for five small functions.
- **`set_team` details are `team: [%{species, level}]`.** Each named member is taken from the Team, then the PC box (first species match, removed from where it was), with the named level; a level left out keeps that member's level, and a new species with no level is refused ("What level is Taillow?"). Team members not taken go to the end of the PC box in Team order. 0 or more than 6 named is refused. Alternative, a string to parse: the model already splits names and levels well and a list validates cleanly.
- **No-change rule in `run/3`.** After `change/4`, a Team kind whose new Team and box equal the current ones returns the confirm without writing an Event. This makes `set_lead`, `set_team` and `set_level` repeats idempotent, and keeps `undo` from undoing a no-op.
- **Repeat guard widened by one query.** `deposited` and `withdrawn` change Progress each time, so the no-change rule cannot catch a doubled call. They check only the Guest's last Event: same kind and species inside the existing 2 minutes means "already logged". The last Event, not a window of them, so "deposit Wingull, undo, deposit Wingull" still works (undo deletes the Event).
- **`slot` is screen-only.** Events accept it on `deposited`, `set_lead`, `set_level`, `released` (Team position) and `withdrawn` (PC box position); when the member at that slot is not the named species the Event is refused ("That Pokémon moved, so nothing changed."), which guards a stale screen. The tool schema leaves it out to save tokens.
- **`level_up` kept, hidden from the tool.** Old Events and tests use it; the tool enum is `Events.kinds() -- ["level_up"]` so the model picks `set_level`.

## Risks / Trade-offs

- [More schema tokens slow the agent stage] → keep descriptions to one line per kind; measure p50 and p95 before and after; Answer time p95 must stay at most 8 s.
- [`set_team` from a misheard Question moves members to the box] → nothing is deleted and one `undo` restores it.
- [A species the Guest names past the Spoiler horizon joins the Team, and `find_pokemon` answers for Team members] → same as `caught` today; the probe cases check confirms name only what the Guest said.

## Migration Plan

None: no schema change. Rollback is a revert; Events of the new kinds stay undoable because `undo` reads only `previous`.
