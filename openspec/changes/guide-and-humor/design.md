# Design: guide-and-humor

## Context

`locations.json` is hand-written and is the only horizon map (fail closed, ARCHITECTURE.md decision 8). Today it lists 14 locations, Littleroot Town to Dewford Town; Abhishek asked on 2026-11-16 to reach gym 3 (Wattson, Mauville City). `Maya.Horizon` already knows all 8 gyms, so only the location rows change. Each row maps one location to one map, and `find_pokemon` joins encounters on that map. Progress already has a `humor` column, seeded at 75 and read into the prompt, but nothing writes it. `Tools.encode/2` already knows `{:logged, line, progress}` and `{:refused, line}` from `log_event`.

## Goals / Non-Goals

**Goals:** notes that can never name a place past their own horizon, Littleroot Town to Mauville City; one Dial changeable by voice.

**Non-Goals:** search by free text or embeddings (SQL by location name only, decision 4); places after gym 3.

## Decisions

- **New rows and their badges.** In story order the Guest reaches Granite Cave from Dewford Town to deliver the letter, so it is 1 badge, like Dewford. Mr. Briney's boat to Slateport City crosses Routes 107 to 109, and Route 110 leads north to Mauville City; these are tagged 2 badges, the gym 3 leg, so at 1 badge (Next gym Brawly) nothing about Slateport or Mauville is said. Route 117, Verdanturf Town, Route 111 and New Mauville stay unlisted: they belong to gym 4 and later.
- **Granite Cave is one row on `MAP_GRANITE_CAVE_1F`.** One location, one map keeps the table and `find_pokemon` unchanged; encounters on B1F, B2F and Steven's room stay unlisted, so they fail closed instead of leaking.
- **One note per location, tagged with the location's `badges_required`.** Keeps the horizon in one table. A note may name only listed locations whose `badges_required` is at most its own; a test checks every note's text against every other location name and the forbidden list. So Rustboro City's note (0) cannot point to Route 116 (1), and Dewford Town's note (1) cannot point to Slateport City (2); the hint from `past_horizon` covers "what next" after each gym.
- **Unlisted means `past_horizon`, not `not_found`.** Answering "not found" for a made-up name and "further ahead" for Lavaridge would tell the Guest Lavaridge exists.
- **`set_setting` reuses the `log_event` result shapes.** `{:logged, line, new_progress}` and `{:refused, line}` encode as `confirm` and `refused`, so the loop and the #118 honesty check treat both write tools the same way.
- **Humor is a setting, not an Event.** Events change the player's game (ADR-006); the Dial changes Maya. Saying a new value replaces it.
- **Name matching:** trimmed, case-insensitive, a leading "the" dropped; no fuzzy match, so a mishearing becomes `past_horizon` with a hint rather than the wrong place.
- **Two build PRs.** Part A (locations, notes, `search_guide`) and part B (`set_setting`) share no code; splitting keeps each under 2h.

## Risks / Trade-offs

- [Unreviewed notes give wrong directions out loud (PRODUCT.md risk)] → notes are built only from Maya's data files; wrong ones get fixed as found.
- [A Guest sails to Slateport City before battling Brawly] → at 1 badge Slateport is `past_horizon` with the Brawly hint. Fail closed is the safe side; Abhishek can move the row to 1 badge if he prefers.
- [Lower Granite Cave floors] → their wild Pokémon are not returned; acceptable, as no answer beats a spoiler.
- [A Guest at an unlisted location asks "where now?"] → `past_horizon` with the Next gym hint, never a guess.
