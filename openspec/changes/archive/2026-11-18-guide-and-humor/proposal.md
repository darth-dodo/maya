# Proposal: guide-and-humor

## Why

PRODUCT.md promises "I'm stuck, where now?" from Walkthrough notes and "Maya, humor 60 percent" by voice. Neither exists: there is no `search_guide` or `set_setting` tool, so Maya either says "Not sure" or, worse, answers from memory (ADR-004). This finishes #41; `log_event` already shipped in #86. Abhishek ranked it second on 2026-11-15 ("Yes") and widened the notes to gym 3 on 2026-11-16 ("Do till gym 3"). Size: 3h in two build PRs (part A 2h, part B 1h), since one PR would pass the 2h block limit.

## What Changes

Part A (guide, 2h):

- **Locations to Mauville**: `priv/data/locations.json` gains seven rows, so the listed route reaches the gym 3 city: Granite Cave (`MAP_GRANITE_CAVE_1F`), Route 109 and Slateport City at 1 badge (Mr. Briney sails there from Dewford before Brawly; Abhishek, 2026-11-16), and Route 107, Route 108, Route 110 and Mauville City at 2 badges. That makes 21 listed locations. Every other place stays unlisted (fail closed). This also widens what `find_pokemon` returns at 2 badges, which is the point: a Guest heading to Wattson can ask about Route 110.
- **Walkthrough notes**: a hand-written `priv/data/walkthrough_notes.json`, one short original note per listed location from Littleroot Town to Mauville City (21 notes), written by Claude from Maya's game data (encounters, trainers, locations), each tagged with `badges_required` equal to its location's. Never copied from a guide site. Never touched by `mix maya.fetch_data`.
- **Import**: a new `walkthrough_notes` table (`location`, `badges_required`, `text`), loaded by `mix maya.import`. The import fails when a note's location is not in `locations.json` or its `badges_required` is below its location's (fail closed).
- **Tool `search_guide(location)`**: `location` optional, defaulting to the Guest's current location. Returns `{:ok, fact}` with the location and its note; `{:error, :past_horizon}` for a location past the horizon or not listed (fail closed: Maya never tells a later place apart from a made-up one); `{:error, :not_found}` for a listed location inside the horizon with no note. Filtered in SQL on `badges_required`.
- **Prompt and probes**: the `search_guide` line and the guide probe cases, at 0, 1 and 2 badges.

Part B (Humor dial, 1h):

- **Tool `set_setting(name, value)`**: `name` is `humor` only, `value` 0 to 100. Writes the Humor dial on the Guest's Progress and returns a confirm line ("Humor set to 60 percent."), which the rest of the turn uses. Any other Dial, including spoilers, or a value out of range gets a refused line. Not an Event, so no undo.
- **Prompt and probes**: the `set_setting` line; Maya never says a Dial changed unless `set_setting` confirmed it (#118); the Dial probe cases.

Out of scope: embeddings, notes past Mauville City, Route 117, Verdanturf Town and New Mauville (after gym 3), the lower Granite Cave floors, other Dials by voice, undo for settings (PHASE_2.md).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent`: new tools `search_guide` and `set_setting`, prompt lines, probe cases.
- `game-data`: locations through Mauville City; Walkthrough notes file, table and import checks; Humor dial written to Progress.
- `spoiler-horizon`: the unlisted location example moves from Route 110 (now listed) to Route 111.

## Impact

- Code: `priv/data/locations.json`, `lib/maya/game_data.ex`, `lib/maya/agent/facts.ex`, `lib/maya/agent/tools.ex`, `lib/maya/agent/prompt.ex`, a migration, `priv/data/walkthrough_notes.json`.
- Tests: locations and import checks, Horizon, Facts, Tools, prompt, probes in `test/fixtures/spoiler_probes.json`.
- Docs: PRODUCT.md and ARCHITECTURE.md say "to Mauville" instead of "to Dewford".
- Voice loop: two more tool definitions per request; agent-stage latency measured before and after in each part.
- Depends on `sunday-goal` (#40) for the probe file and on #118 for the honesty check. `trainers-items-readiness` (#121) depends on part A for the Mauville rows.
- Issue: #41. Part A's PR says "Part of #41"; part B's PR says "Closes #41" and archives the change.
