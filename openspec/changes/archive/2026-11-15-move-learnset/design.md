# Design: move-learnset

## Context

`mix maya.fetch_data` already downloads each species' default `pokemon` resource to read its Generation III types. That response also carries `moves[].version_group_details[]` with `version_group`, `move_learn_method` and `level_learned_at` ([PokeAPI pokemon](https://pokeapi.co/docs/v2#pokemon)). `Maya.Horizon` is pure over Progress; gym parties live in `trainers` and `trainer_pokemon`.

## Goals / Non-Goals

**Goals:** level-up moves per species for Emerald, filtered by a level horizon before they reach the model.

**Non-Goals:** a `moves` table with type and power (ARCHITECTURE.md lists one; not needed to answer "what does Mudkip learn next?").

## Decisions

- **Level horizon = Next gym ace level.** "Levels reachable before the Next gym" needs one number. The ace's level is in Maya's data, moves with the badge count, and matches how players train for a gym. Alternatives: the highest wild level inside the horizon (too low, 7 to 9 near Rustboro, hides Water Gun at 10), a fixed table per badge (one more hand table to keep right).
- **`Horizon.level_cap(progress, ace_level)` stays pure:** the Tools shell reads the ace from trainer data and passes the level in, like `gym_counter` does.
- **Store only `emerald` rows, keep `method`.** TM and HM rows come later through the same column without a migration.
- **Inclusive cap.** A move at exactly the ace level is returned (Bide at 15 for Mudkip).
- **Species rule shared with `find_pokemon`.** One function decides whether a species is inside the horizon, so the two tools never disagree.

## Risks / Trade-offs

- [A Guest over-levels past the ace] → the cap is the higher of the ace level and the Team's highest level, so Maya can still answer for a level 20 Mudkip at 0 badges.
- [PokeAPI renames a version group] → the parse test uses a fixture; a fetch that yields zero rows for a species with level-up moves fails loudly.
