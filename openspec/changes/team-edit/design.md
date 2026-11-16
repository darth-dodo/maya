# Design: team-edit

## Context

`TalkLive` holds `progress`, `card` and `talk_state` (from the hook's `talk_state` event). The Conversation broadcasts `{:progress, p}` after Events in a turn (#160), and each turn's prompt reads the latest Progress row, so a screen edit is seen by the next Question with no extra wiring. `team-collapse` (#159) wraps `#team` in a `<details>` summary.

## Decisions

- **Server-driven editor, no hook.** A chip is a `<button phx-click="edit_mon" phx-value-slot>`; the editor is rendered from an `editing` assign (`nil`, `{:team, slot}` or `:box`). Actions are `phx-click` events that call `Maya.Events.log(progress, kind, details)` with the species and `slot`, then assign the returned Progress and card. Alternative, a JS dialog with `showModal`: needs a hook or a new JS file and focus handling we get from `Phoenix.LiveView.JS.push_focus/pop_focus` and `focus_first`.
- **Overlay, fixed position.** The editor is a fixed panel above the band content, so opening it changes no layout height (#74). It is not a modal `<dialog>`; it has `role="dialog"`, `aria-modal="false"`, a heading and a Close button, and Escape closes it via `phx-window-keydown`.
- **Idle only.** `edit_mon` and every action are ignored unless `talk_state` is `"idle"`, and a `talk_state` change away from idle clears `editing`. A hold can never be blocked or resized by the editor.
- **Level input.** A number input (1 to 100) with a Save button in a small form, `phx-submit`; validation is Events' own (`Levels go from 1 to 100.` comes back as the refused line), not a second rule in the view.
- **Undo is the Events `undo`.** The Undo button appears after a confirmed action and logs `undo`; it undoes the Guest's last Event, voice or screen, which matches the voice rule.

## Risks / Trade-offs

- [A screen edit and a turn's Event race] → `Events.log/3` locks the Progress row per Guest; the later write sees the earlier one.
- [Undo after a voice Event undoes that one] → same rule as voice; the confirm names what was undone only as "Undone, that Event is off the record."
- [Fixed overlay covers the chat] → it is small, closes on Close, Escape or a hold, and only shows while idle.
