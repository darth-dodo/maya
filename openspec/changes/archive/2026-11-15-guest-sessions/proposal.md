# Proposal

GitHub Issue: #61

## Why

Maya has one Conversation and one Progress for everyone. Test noise, a second phone or anyone with the link share one history and one badge case. Every browser should get its own Conversation and Progress, keyed by a random id in Phoenix's signed session cookie, the way habla-hermano isolates guests in app code.

## What Changes

- A plug in the browser pipeline puts a random `guest_id` (16 random bytes, url-safe Base64) in the signed session when it is missing. The Talk screen reads it on mount.
- One Conversation process per guest, found by `guest_id`. It stops after 30 idle minutes and reloads its turns from Postgres on the next visit.
- `turns` and `progress` gain a `guest_id` column (indexed; one Progress row per guest). Existing rows move to the guest `legacy`, so nothing is lost.
- A guest's Progress is seeded from `priv/progress.json` the first time it is read. The release import seeds game data only.
- The agent, its tools and the Spoiler horizon read the asking guest's Progress.
- A "Start fresh" button with an in-page confirm step gives the browser a new `guest_id`: a new empty Conversation and seed Progress. Old rows stay in Postgres.
- ADR-008 "Guest sessions" partly supersedes ADR-006 ("one Conversation, kept forever").

Out of scope: accounts and login (#49), per-IP rate limits, a threads list, carrying a guest across devices, deleting old guests' rows. New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities
- `guest-sessions`: the guest id in the signed cookie, per-guest isolation of turns and Progress, and Start fresh.

### Modified Capabilities
- `voice-loop`: one Conversation per guest instead of one in total, with an idle stop.
- `game-data`: Progress is seeded per guest on first use, not by the import.

## Impact

- New: `lib/maya_web/plugs/guest_id.ex`, `lib/maya_web/controllers/fresh_controller.ex`, a migration adding `guest_id`, `docs/adr/008-guest-sessions.md`, tests.
- Changed: `lib/maya/{conversation,game_data,agent,release}.ex`, `lib/maya/voice/turn.ex`, `lib/maya_web/{router,endpoint}.ex`, `lib/maya_web/live/talk_live.ex`, `lib/mix/tasks/maya.compare_models.ex`, PRODUCT.md, ARCHITECTURE.md, GLOSSARY.md, PHASE_2.md, ADR-006 and the ADR index.
- No new dependencies; the CSP is unchanged. The voice loop path gains one indexed Progress read per Question (it already read Progress).
