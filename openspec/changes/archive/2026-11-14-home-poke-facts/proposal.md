# Proposal

GitHub Issue: #32

## Why

The home page is static. A few rotating Poke facts give it some life and show Maya's voice before any voice feature exists. The home page has no Progress, so the facts must stay inside the spoiler horizon of a brand new save: before the first gym.

## What Changes

- A "Poke facts" section between the hero (`#maya-hero`) and the badge case: a list `#poke-facts` of 12 short facts, each an item with class `poke-fact`.
- Facts name only the Hoenn starters (Mudkip, Treecko, Torchic) and wild Pokemon from the land encounters of Routes 101 to 104 and Petalburg Woods. Starter evolutions give the level only, never the evolved form. No gym leader, badge, later place, team or story event.
- Every fact is checked against pret/pokeemerald `wild_encounters.json` or PokeAPI; the source table is in `design.md` (ADR-004 spirit).
- Rotation is CSS only: all facts are in the server-rendered HTML and an animation shows one at a time, about 8 seconds each, looping. Screen readers get the full list. With `prefers-reduced-motion` there is no animation and only the first fact shows visually.
- Out of scope: facts past the first gym or based on Progress, JavaScript rotation or controls, facts from the database or agent tools. New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `landing-page`: adds the requirement "Rotating Poke facts".

## Impact

- `lib/maya_web/controllers/page_html.ex` (facts list), `lib/maya_web/controllers/page_html/home.html.heex`, `assets/css/app.css`, `test/maya_web/controllers/page_controller_test.exs`.
- No JavaScript, no CSP change, no new dependencies.
