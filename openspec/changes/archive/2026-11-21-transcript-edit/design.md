# Design

## Context

See proposal.md, Why. Today `Conversation.finished(:stt, {:ok, question, progress}, state)` starts the agent Task at once, and the Question first reaches the screen in `speak/3` (the `{:turns, ...}` broadcast). The hook goes `uploading` to `waiting` on the server's `heard` push and drops audio chunks unless `waiting` or `speaking`. `cut/1` already cancels whatever stage is in flight when a new Question or a barge-in arrives.

## Goals / Non-Goals

**Goals:** a Guest can catch and fix a misheard name before it costs an Answer; typing is a first-class Question; the countdown is measured, short and configurable.

**Non-Goals:** editing stored turns; a countdown for typed Questions; changing the empty transcript path.

## Decisions

- **The countdown overlaps the agent call (decided by Abhishek, 2026-11-21).** After STT the Conversation starts the agent Task at once, as before, marks the turn `pending` and sets a `Process.send_after(self(), {:confirm_end, ref}, confirm_ms)` timer. Untouched Questions get no added latency. The timer only closes the edit window: it broadcasts `{:question, text}`. An Answer that is ready first starts speaking and ends the window early. Alternative: wait the countdown before the agent; rejected after #40 measured p50 4.95 s and p95 8.21 s Answer time, a 2 s wait would break both targets.
- **Edit or cancel discards the in-flight Answer.** `edit_pending` (the tap) kills the agent Task the same way `cut/1` does in the agent stage (never spoken, never stored) and moves the stage to `:editing`. `send_pending` validates (trim, 1 to 300 characters), reads Progress again and asks the agent the edited text as a new Question on the same hold turn id. `cancel_pending` sets `current: nil`; TalkLive pushes `question_cancelled` so the hook returns to `idle`. A write the discarded run already made stays, as with a barge-in during the agent stage today: the card redraws (`{:progress, ...}`) so the Guest sees it and can say "undo".
- **Broadcast `{:pending, text, ms}`** from the Conversation; TalkLive renders `#pending-question` with the countdown seconds. The countdown display is a CSS animation of `ms` length plus a server-rendered seconds number, so it needs no ticking server pushes. `prefers-reduced-motion` turns the animation off.
- **The tap target is the text field itself (iOS keyboard).** iOS opens the keyboard only for a focus inside the user's gesture; a server round trip (`JS.focus` after a patch, or `JS.show`, which waits two animation frames) is too late. So the pending text renders in a `textarea` (`#edit-input`): the tap focuses it natively, and `phx-focus` tells the server to stop the countdown. The type button runs `JS.focus` on `#type-input`, which is always rendered (transparent until open) so the focus lands in the same click. After the countdown the field turns `readonly` in place, so nothing changes size under a finger (#74).
- **Cancel stores nothing.** Picked over "stored as cancelled": a cancelled Question has no Answer, and `turns.answer` is required. A cancel is logged at info with no text, so the count is still visible.
- **Typed Questions reuse the agent stage.** `Conversation.typed(id, text)` cuts the current turn, reads Progress once inside the agent Task (the STT stage normally does it) and proceeds as after STT, with `typed: true`. TalkLive pushes `typed` to the hook, which moves to `waiting` and sets its release mark to the Send time, so `playback_start_ms` is Send to first sound and the hook accepts the Answer audio.
- **Typed and edited text skip `Vocabulary.correct`.** The Guest wrote it; correcting their own spelling would surprise them.
- **Config:** `config :maya, :voice, confirm_ms: 2000`; tests set it low.

## Risks / Trade-offs

- [A discarded run may already have written an Event (a catch, a level)] → same as a barge-in during the agent stage today: the write stays and the card redraws, so the Guest sees it; the edited Question runs on the fresh Progress.
- [Edits can take long, skewing Answer time] → `confirm_ms` holds the whole edit time (near 0 untouched), so `mix maya.latency` can separate it from the rest.
- [An agent call per discarded Question costs tokens] → only on an edit or a new hold during the countdown, both rare.
- [A typed Question while the hook is `recording`] → the type form is hidden while `recording` or `uploading`.

## Migration Plan

One migration adds `turns.confirm_ms` (integer, null) and `turns.typed` (boolean, default false, not null). Additive; runs in the existing pre-deploy migration. Rollback: revert the PR; the columns can stay.
