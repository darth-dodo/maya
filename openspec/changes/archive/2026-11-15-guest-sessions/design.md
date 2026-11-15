# Design

## Context

Today `Maya.Conversation` already takes an id, but TalkLive always passes `"main"`, `Turn.recent/0` reads every turn and `progress` is one row with `id = 1`. Phoenix keeps the session in a signed cookie (`MayaWeb.Endpoint` `@session_options`), and the LiveView socket reads the same session through `connect_info`.

## Decisions

1. **Guest id in the session.** `MayaWeb.Plugs.GuestId` runs after `fetch_session` in the browser pipeline: `get_session(conn, :guest_id)`, else `put_session` of `Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)`. TalkLive reads `session["guest_id"]` in `mount/3`; LiveView passes the Plug session (string keys) to `mount/3` ([Phoenix.LiveView mount/3](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#c:mount/3)).
2. **Signed, not encrypted.** The cookie store signs by default, so a guest cannot forge another id; `:encryption_salt` would only hide the id from the browser that already holds it ([Plug.Session.COOKIE](https://hexdocs.pm/plug/Plug.Session.COOKIE.html)). We add `max_age` of one year so the guest survives the phone browser closing (`Plug.Session` passes it to the cookie, [Plug.Session](https://hexdocs.pm/plug/Plug.Session.html)).
3. **Registry key `{:conversation, guest_id}`**, `Conversation.start_or_find/1`. The process is `restart: :transient`, so a crash restarts it and an idle stop does not. Idle is the GenServer timeout (30 minutes, `:conversation_idle_ms` in app config for tests) returned from every callback; `handle_info(:timeout)` stops `:normal`. `question/3` calls `start_or_find/1` first, so a Question after an idle stop is not lost.
4. **Migration.** `guest_id` string, not null, added with default `"legacy"` (Postgres fills existing rows), then the default is dropped so code must always set it. `index(:turns, [:guest_id])`, `unique_index(:progress, [:guest_id])`. The old seed inserted `id = 1` by hand, so the migration moves the `progress` id sequence past the max id; otherwise the first new guest collides on the primary key.
5. **Progress per guest.** `GameData.progress(guest_id)` selects the row; when missing it inserts the seed with `on_conflict: :nothing, conflict_target: :guest_id` and selects again, so two racing first reads end with one row without a transaction. `import!/1` no longer seeds Progress.
6. **Agent.** `Maya.Agent.answer(question, turns, guest_id: id)` reads that guest's Progress; tools, prompt and Horizon already take the Progress map. With no `:guest_id` it returns `{:error, :no_progress}` without calling OpenRouter.
7. **Start fresh.** LiveView cannot write the cookie, so the confirm step is a `<.form action={~p"/fresh"} method="post">` (CSRF token included) handled by `FreshController.create/2`, which puts a new guest id and redirects to `/`. The old Conversation idles out.

## Risks

- Cost: every guest can spend OpenRouter and Mistral calls until `Plug.BasicAuth` lands (#49).
- A cleared cookie loses that guest's history and Progress (the rows stay, unreachable).
- Isolation is app code (every query filters by guest id), not row-level security.
- `mix maya.latency` stays global over all guests' turns: it measures the voice loop, not a guest.
