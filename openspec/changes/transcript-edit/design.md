# Design

## Context

See proposal.md, Why. Today `Conversation.finished(:stt, {:ok, question, progress}, state)` starts the agent Task at once, and the Question first reaches the screen in `speak/3` (the `{:turns, ...}` broadcast). The hook goes `uploading` to `waiting` on the server's `heard` push and drops audio chunks unless `waiting` or `speaking`. `cut/1` already cancels whatever stage is in flight when a new Question or a barge-in arrives.

## Goals / Non-Goals

**Goals:** a Guest can catch and fix a misheard name before it costs an Answer; typing is a first-class Question; the countdown is measured, short and configurable.

**Non-Goals:** editing stored turns; a countdown for typed Questions; changing the empty transcript path.

## Decisions

- **The countdown lives in the Conversation.** A new stage `:confirm` holds the pending text and a `Process.send_after(self(), {:confirm, ref}, confirm_ms)` timer. The server is the single source of truth, so a reconnecting screen sees the same pending Question and the existing `cut/1` discards it for free on a new Question or barge-in (a stale `{:confirm, ref}` falls to the existing catch-all `handle_info`). Alternative: a JS-only countdown that sends the text; rejected, it would let the client choose the Question text on every turn and splits state between hook and server.
- **Broadcast `{:pending, text, ms}`** from the Conversation; TalkLive renders `#pending-question` with the countdown seconds. The countdown display is a CSS animation of `ms` length plus a server-rendered seconds number, so it needs no ticking server pushes. `prefers-reduced-motion` turns the animation off.
- **Edit is two events.** `edit_pending` (tap) cancels the timer and moves the stage to `:editing` (no timeout beyond the Conversation's 30 min idle). `send_pending` with `text` validates (trim, 1 to 300 characters) and starts the agent; `cancel_pending` sets `current: nil` and pushes `question_cancelled` so the hook returns to `idle`.
- **Cancel stores nothing.** Picked over "stored as cancelled": a cancelled Question has no Answer, and `turns.answer` is required. A cancel is logged at info with no text, so the count is still visible.
- **Typed Questions reuse the agent stage.** `Conversation.typed(id, text)` cuts the current turn, reads Progress once inside the agent Task (the STT stage normally does it) and proceeds as after STT, with `typed: true`. TalkLive pushes `typed` to the hook, which moves to `waiting` and sets its release mark to the Send time, so `playback_start_ms` is Send to first sound and the hook accepts the Answer audio.
- **Typed and edited text skip `Vocabulary.correct`.** The Guest wrote it; correcting their own spelling would surprise them.
- **No speculative agent call during the countdown.** Starting the agent early and discarding on edit would hide the countdown cost, but `log_event` writes Events and Progress, so a discarded speculative run could record a badge the Guest never confirmed. Rejected.
- **Config:** `config :maya, :voice, confirm_ms: 2000`; tests set it low.

## Risks / Trade-offs

- [The countdown adds about 2 s to every spoken Answer time: p50 target 5 s, p95 8 s are measured from release with it included] → keep it short (2 s), configurable, and measured as `confirm_ms`; with `realtime-transcription` the STT stage shrinks and gives some of it back. If p50 Answer time goes over 5 s, the first lever is `confirm_ms` 1500.
- [Edits can take long, skewing Answer time] → `confirm_ms` holds the whole edit time, so `mix maya.latency` can separate it from the rest.
- [A typed Question while the hook is `recording`] → the type form is hidden while `recording` or `uploading`.

## Migration Plan

One migration adds `turns.confirm_ms` (integer, null) and `turns.typed` (boolean, default false, not null). Additive; runs in the existing pre-deploy migration. Rollback: revert the PR; the columns can stay.
