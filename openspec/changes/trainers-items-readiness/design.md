# Design: trainers-items-readiness

## Context

`trainers.json` holds every party by label (`Calvin1`, `Calvin2`, ...) but not where a trainer stands. In pokeemerald that lives in each map's `scripts.inc` (`trainerbattle_single TRAINER_CALVIN_1, ...`), and `src/data/trainers.h` maps `TRAINER_CALVIN_1` to `sParty_Calvin1`. Item balls are `object_events` in `map.json` whose script is defined in `data/scripts/item_ball_scripts.inc` (`finditem ITEM_POTION`); hidden items are `bg_events` of type `hidden_item`; marts are `pokemart` lists in an interior map's `scripts.inc`.

The listed locations are outdoor maps. Interiors are separate maps (`MAP_RUSTBORO_CITY_MART`, `MAP_PETALBURG_CITY_GYM`).

## Goals / Non-Goals

**Goals:** trainers and items per place, tagged so the Spoiler horizon fails closed.

**Non-Goals:** a general map importer; only listed and hand-listed maps are fetched.

## Decisions

- **Interiors are hand-listed, never inherited.** `MAP_PETALBURG_CITY_GYM` is Norman's gym (badge 5) inside a 0-badge city, and Wally's house gives HM03 Surf after badge 5. Inheriting the city's `badges_required` would leak both. `interiors.json` lists each mart and gym inside the horizon with its own value; anything else is never fetched.
- **Gifts are hand-written.** `giveitem` sits behind story flags a parser cannot read reliably. `gifts.json` lists HMs and key items inside Littleroot to Dewford (from the map scripts) with a `badges_required`; an unlisted gift is never returned.
- **First party only.** Map scripts reference `TRAINER_X_1`; rematch parties come from the Match Call table, so trainers are stored only through their map script reference. Calvin on Route 102 is Calvin1 (Poochyena 5), never Calvin2 (Mightyena 27).
- **`items` from `items.h`** gives `not_found` versus `past_horizon` without naming where a later item is.
- **`ready` rule.** Ready when any Team member is at or above the ace's level, or has a 2x or better multiplier against the ace and is at most 3 levels below it. It reuses `gym_counter`'s matchup code; the threshold is in one place so it can be tuned.

## Risks / Trade-offs

- [A hand table is wrong] → each row cites the pokeemerald file it came from; a test checks every `gifts.json` and `interiors.json` map exists in the fetched data.
- [Map directory names] → derived from the map constant (`MAP_ROUTE102` to `Route102`); the fetch fails loudly on a 404.
