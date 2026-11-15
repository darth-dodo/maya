# 008: Guest sessions

- Status: Accepted (Abhishek, 2026-11-15)
- Date: 2026-11-15

## Context
ADR-006 kept one Conversation forever and one Progress row. Since the Render deploy, test runs, a second phone and anyone with the link all write into that one history and badge case. Login is not built yet (#49). habla-hermano solved the same problem for guests by keying every row by a guest id and filtering in app code.

## Decision
- **Guest id in the signed cookie.** `MayaWeb.Plugs.GuestId` in the browser pipeline puts `guest_id` (16 bytes from `:crypto.strong_rand_bytes/1`, url-safe Base64) in the Phoenix session when it is missing. The cookie is signed, so a guest cannot forge another id; it is not encrypted, because it holds only the id its own browser already has ([Plug.Session.COOKIE](https://hexdocs.pm/plug/Plug.Session.COOKIE.html)). It has a one year `max_age`, so closing the phone browser keeps the guest ([Plug.Session](https://hexdocs.pm/plug/Plug.Session.html)). TalkLive reads it from the session in `mount/3` ([Phoenix.LiveView mount/3](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#c:mount/3)).
- **One Conversation per guest.** The Registry key is `{:conversation, guest_id}`. A Conversation stops normally after 30 idle minutes (transient restart: crashes still restart) and reloads its turns from Postgres on the next visit or Question.
- **Per-guest rows.** `turns.guest_id` and `progress.guest_id` (not null, indexed; one Progress row per guest). Every turns and Progress query filters by it. A guest's Progress is seeded from `priv/progress.json` on first read; the release import seeds game data only. Rows from before this ADR belong to the guest `legacy`.
- **Agent.** The agent, tools, prompt and Spoiler horizon get the asking guest's Progress.
- **Start fresh.** A button with an in-page confirm step posts to `/fresh`, which puts a new guest id in the session. The old guest's rows stay in Postgres.

## Consequences
- Easier: test noise and other people never share a history or Progress; each phone browser is its own player.
- Cost: until `Plug.BasicAuth` lands (#49), any visitor is a guest who can spend OpenRouter and Mistral calls. Rate limits per IP stay out of scope.
- Losing the cookie (cleared site data, another browser or device) loses that guest's history and Progress. The rows stay in Postgres, unreachable from the screen.
- Isolation is app code (every query filters by `guest_id`), not Postgres row-level security. A missing filter would leak; tests cover two guests.
- `mix maya.latency` stays global over every guest's turns: it measures the voice loop.
- Old guests' rows are never deleted; a retention window is in PHASE_2.md (privacy line).
- Partly supersedes ADR-006: "one Conversation, kept forever" becomes one per guest. Progress and turns in Postgres still stand.
