# Proposal

GitHub Issue: #77 (split out of #41)

## Why

Maya forgets what the Guest tells her. "I just earned Roxanne's badge" changes nothing, because the agent only has read-only tools and every Guest stays at the seed Progress (0 badges, Mudkip level 5). After badge 1 the `locations` table also ends at Rustboro City, so the whole way to Dewford counts as past the Spoiler horizon.

## What Changes

- A `log_event(kind, details)` tool for the agent. Kinds: `badge_earned`, `caught`, `evolved`, `level_up`, `moved`, `undo`. Each Event is validated against Maya's own data, written to a new `events` table and applied to the Guest's Progress in one transaction. The tool returns a one line confirm ("Stone Badge logged. Mudkip would approve.").
- Validation: only the Next gym's badge can be logged (an earlier one is already earned); a later or unknown gym gets one polite refusal that names only the Next gym, so it never confirms a later gym exists. Species must be in game data, levels 1 to 100, the Team holds at most 6, a move must name a location inside the Spoiler horizon.
- Undo: when the Guest says "no" or "undo that", the agent calls `log_event` with `undo`, which restores the Progress from before the Guest's last Event and removes that Event.
- The system prompt tells the model to call `log_event` when the Guest reports progress and to say its confirm line. The prompt is built from the latest Progress row each turn, and the rest of the turn uses the updated Progress.
- `locations` gains Route 116, Rusturf Tunnel, Route 105, Route 106 and Dewford Town (badges required 1). Everything past Dewford stays unlisted, so it fails closed. The release import already reloads `locations` on every deploy (#60).

Out of scope: the Humor dial by voice (`set_setting`) and Walkthrough notes (#41), event history views, undo beyond the last Event chain. New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities
- `events`: the `log_event` tool, its validation, the confirm and refusal lines, the transactional write and undo.

### Modified Capabilities
- `agent`: the system prompt asks for `log_event` and the tool list grows to three.
- `game-data`: `locations` extends through Dewford Town.

## Impact

- New: a migration for `events`, `lib/maya/events.ex`, tests.
- Changed: `lib/maya/agent.ex`, `lib/maya/agent/{tools,prompt}.ex`, `lib/maya/horizon.ex` (badge names), `lib/maya/game_data.ex` (Progress carries its `guest_id`), `priv/data/locations.json`, ARCHITECTURE.md 3 and 4.
- No new dependencies. The voice loop gains a write only on turns where the Guest reports progress (one Supabase round trip in the agent stage).
