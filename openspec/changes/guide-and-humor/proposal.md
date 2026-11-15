# Proposal: guide-and-humor

## Why

PRODUCT.md promises "I'm stuck, where now?" from Walkthrough notes and "Maya, humor 60 percent" by voice. Neither exists: there is no `search_guide` or `set_setting` tool, so Maya either says "Not sure" or, worse, answers from memory (ADR-004). This finishes #41; `log_event` already shipped in #86. Abhishek ranked it second on 2026-11-15 ("Yes"). Size: L (2h on the board).

## What Changes

- **Walkthrough notes**: a hand-written `priv/data/walkthrough_notes.json`, one short original note per listed location from Littleroot Town to Dewford Town (14 notes), written by Claude from Maya's game data (encounters, trainers, locations), each tagged with `badges_required` equal to its location's. Never touched by `mix maya.fetch_data`.
- **Import**: a new `walkthrough_notes` table (`location`, `badges_required`, `text`), loaded by `mix maya.import`. The import fails when a note's location is not in `locations.json` or its `badges_required` is below its location's (fail closed).
- **Tool `search_guide(location)`**: `location` optional, defaulting to the Guest's current location. Returns `{:ok, fact}` with the location and its note; `{:error, :past_horizon}` for a location past the horizon or not listed (fail closed: Maya never tells a later place apart from a made-up one); `{:error, :not_found}` for a listed location inside the horizon with no note. Filtered in SQL on `badges_required`.
- **Tool `set_setting(name, value)`**: `name` is `humor` only, `value` 0 to 100. Writes the Humor dial on the Guest's Progress and returns a confirm line ("Humor set to 60 percent."), which the rest of the turn uses. Any other Dial, including spoilers, or a value out of range gets a refused line. Not an Event, so no undo.
- **Prompt**: lines for `search_guide` ("where now?", "what is in this place?") and `set_setting`; Maya never says a Dial changed unless `set_setting` confirmed it (#118).
- **Probe cases**: guide and Dial cases for the spoiler probe set (#40).

Out of scope: embeddings, notes past Dewford, other Dials by voice, undo for settings (PHASE_2.md).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent`: new tools `search_guide` and `set_setting`, prompt lines, probe cases.
- `game-data`: Walkthrough notes file, table and import checks; Humor dial written to Progress.

## Impact

- Code: `lib/maya/game_data.ex`, `lib/maya/agent/facts.ex`, `lib/maya/agent/tools.ex`, `lib/maya/agent/prompt.ex`, a migration, `priv/data/walkthrough_notes.json`.
- Tests: import checks, Facts, Tools, prompt, probes in `test/fixtures/spoiler_probes.json`.
- Voice loop: two more tool definitions per request; agent-stage latency measured before and after.
- Depends on `sunday-goal` (#40) for the probe file and on #118 for the honesty check.
- Issue: #41.
