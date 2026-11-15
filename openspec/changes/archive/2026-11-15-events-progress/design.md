# Design

## Context

Progress (badges, Team, location, humor) is one row per Guest (ADR-008), seeded from `priv/progress.json`, read once per turn and handed to the agent (since #80 the Conversation reads it before STT and passes it as `progress:`). ADR-006 already decided that Events (`log_event`) update Progress in the same transaction as the Event row and that `undo` reverts the last Event. The agent tools are a thin shell (`Maya.Agent.Tools`) over a pure core (`Maya.Agent.Facts`); the gym order and leader names live only in `Maya.Horizon`.

## Goals / Non-Goals

Goals: the six kinds in Issue #77, validation from Maya's own data, a confirm line, undo, and locations through Dewford Town.

Non-goals: `set_setting` (humor by voice) and Walkthrough notes (#41); an Event history screen; tying undo to "the next turn" by turn id.

## Decisions

### Pure change, thin writer
`Maya.Events.change(progress, kind, details, data)` is pure: Progress plus the Event plus two lookups (`species` by name, the `locations` list) in, `{:ok, new_progress, confirm}` or `{:refused, line}` out. `Maya.Events.log(guest_id, kind, details)` runs it inside `Repo.transaction/1` after reading the Progress row `FOR UPDATE`, inserts the Event with the previous Progress snapshot, and updates the row. A refusal rolls back and writes nothing. Two racing Events for one Guest serialise on the row lock.

### Undo by snapshot
Each Event row keeps `previous` (badges, Team, location before the Event). `undo` takes the Guest's newest Event, writes its `previous` back and deletes the row, all in one transaction. A second undo then reverts the Event before it. Alternative considered: an `undo` Event that toggles; rejected because undoing an undo is a redo nobody asked for. Shortcut: undo is not limited to the turn right after the Event; the prompt asks for it only then.

### Refusals never confirm a later gym
A badge is accepted only when it is the Next gym's badge (by leader name or badge number). An earlier one is "already" earned, since the Next gym is the first badge not earned. A later leader, an unknown leader and a badge number past the Next gym all get the same line, "I can only log <Next gym leader>'s badge next.", so the reply is the same whether Wattson exists or not (ADR-004, Spoiler horizon). A move to a location outside the horizon (later or unlisted) gets one line that names no place.

### Badge names
The confirm line says "Stone Badge logged." The 8 badge names join the hand-written gym list in `Maya.Horizon`, the one place the gym order lives (pokeemerald numbers them `FLAG_BADGE01_GET` to `FLAG_BADGE08_GET` in `include/constants/flags.h`; names from https://bulbapedia.bulbagarden.net/wiki/Badge#Hoenn_League). Only the Next gym's badge and earlier ones ever reach the model.

### Tool result shape
`log_event` returns `{"confirm": "..."}` or `{"refused": "..."}`. The agent loop threads Progress through the round with `Enum.map_reduce/3`, so a `gym_counter` after a logged badge in the same turn sees the new Next gym. Progress carries its `guest_id` (selected with the row) so the tool knows whose row to write without a new argument.

### Evolutions from data
`evolved` is accepted only when the `to` species is in the `from` species' `evolutions` in game data (PokeAPI chains, already imported). The Team slot keeps its level.

### Locations through Dewford
New rows, `badges_required` 1, map ids from pokeemerald `data/maps/map_groups.json` (the same ids `wild_encounters.json` uses):

| Location | Map | Why 1 badge |
|---|---|---|
| Route 116 | `MAP_ROUTE116` | East of Rustboro City; the story sends you there after Roxanne's badge |
| Rusturf Tunnel | `MAP_RUSTURF_TUNNEL` | The entrance is on Route 116 |
| Route 105 | `MAP_ROUTE105` | Mr. Briney's boat to Dewford sails after the Devon errand that follows badge 1 |
| Route 106 | `MAP_ROUTE106` | Same boat route |
| Dewford Town | `MAP_DEWFORD_TOWN` | Brawly's gym: inside the horizon once he is the Next gym |

Route 104 (`MAP_ROUTE104`, both the south part and the north part past Petalburg Woods) and Petalburg Woods stay at 0: pokeemerald has one map per route, so "Route 104 north" is the existing row, and you walk it to reach Rustboro City before badge 1. Granite Cave, Route 107 and everything past Dewford stay unlisted, so they fail closed. Sources: https://github.com/pret/pokeemerald/blob/master/data/maps/map_groups.json and https://github.com/pret/pokeemerald/blob/master/src/data/wild_encounters.json.

Deploy: `Maya.Release.migrate/0` already runs `import_data/0` on Render's pre-deploy (#60), which replaces `locations` from `priv/data/locations.json`, so the new rows land with the migration.

## Risks / Trade-offs

- The model may not call `log_event` for a casual mention. Mitigation: a prompt rule with examples; the phone check verifies it on the real model.
- An Event write adds one Supabase round trip (Frankfurt to Ireland) to the agent stage on turns that log one. Accepted: it is the Answer's content, and only those turns pay it.
- Undo reaches further back than one turn if the Guest keeps saying "undo". Accepted for the MVP.
