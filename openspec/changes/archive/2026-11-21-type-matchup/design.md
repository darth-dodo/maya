# Design: type-matchup

## Context

See proposal.md, Why. The chart is already imported (`type_matchups`, only the pairs that are not 1x, 110 rows) and `GameData.type_chart/0` returns it as a map. `Facts.gym/1`, the private `inside?/2` and the `find_pokemon` horizon rule (`Facts.places/3`, Team members always inside) already decide what a player may hear about.

## Goals / Non-Goals

- Goal: one read tool that answers three Question shapes with no new chart data.
- Non-goal: a move or ability model. Matchups stay type on type, like `gym_counter` (its "rates types, not moves" shortcut).

## Decisions

1. **One tool, optional `attacker`.** "Water on Geodude?", "What is good against Roxanne?" and "Why is Fire weak to Water?" differ only in whether an attacker is given. One definition keeps the request smaller than three. Alternative: separate `weak_to` and `why` tools, rejected for request size.
2. **`defender` resolution order: type, then gym leader, then Pokémon.** A type name is never past the horizon. A leader goes through `Facts.gym/1` and the same `inside?` check as `gym_counter`, and means that leader's ace (highest level, last on a tie). A Pokémon is inside when it is on the Team, has a wild place inside the horizon, or is in the party of a gym inside the horizon (so Geodude at 0 badges, from Roxanne's party). Unknown names, and Fairy, are `not_found`.
3. **Reasons in their own table, read with the chart.** `type_reasons` mirrors how Walkthrough notes are checked then loaded. The checker is pure (decoded JSON in, problems out), runs before the import transaction, and fails closed. Rows carry the chart multiplier so a flipped pair (Fire on Water at 2) is caught, not only an absent one.
4. **Original text is a review check, not a code check.** The checker enforces length and banned words; `factory:review` confirms the lines are Maya's own wording.
5. **Fact shape**: `defender` (name and types), then either `multiplier` and `reasons`, or `good` (type, multiplier, reason) and `avoid` (type, multiplier, reason), sorted strongest first.

## Risks / Trade-offs

- [Abilities change real outcomes (Levitate makes Ground miss)] → Out of scope; the prompt says the multiplier is by type.
- [Another tool definition lengthens every request] → Short description; size and agent latency measured before and after.
- [Reason lines read as facts] → The prompt says the multiplier first and the reason only as flavour; the reasons are checked against the chart.

## Migration Plan

One migration adds `type_reasons`; `mix maya.import` fills it on deploy (pre-deploy runs migrations). Rollback: drop the table and the tool definition.
