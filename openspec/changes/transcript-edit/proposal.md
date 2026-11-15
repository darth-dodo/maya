# Proposal

GitHub Issue: #95 (part of #75, Block 7: Realtime transcription). Decided by Abhishek on 2026-11-15.

## Why

When STT mishears a Pokémon name, the Guest only finds out from a wrong Answer, and the only fix is to ask again out loud. Showing the transcript for a moment before it goes to the agent, with a tap to fix it, turns a wasted turn into a two second correction. A keyboard option covers noisy rooms and names that STT keeps missing. Both work with today's batch STT and stay useful after `realtime-transcription`.

## What Changes

- **Auto-send, tap to edit.** After release, the final transcript shows in the Guest's bubble with a visible countdown (default 2 s, configurable, reduced motion respected). Untouched, it goes to the agent. A tap during the countdown stops it and opens an inline editor (prefilled text field, Send and Cancel, 44 pt targets). Send uses the edited text; Cancel discards the Question: no agent call and no turn stored.
- **Hold again discards.** A hold during the countdown or the editor discards the pending Question and records a new one. Barge-in while Maya speaks works as today.
- **Type instead of speaking.** A small keyboard button next to the Talk button opens a text field; Send goes to the same agent path with no STT. The turn records that it was typed and its STT stages stay blank.
- **Latency.** A new stage `confirm_ms` (STT done to agent start) is stored per turn and printed by `mix maya.latency`. Answer time stays measured from release, countdown included.

Out of scope: realtime partial text (`realtime-transcription`), editing past turns, voice commands to edit, speculative agent calls during the countdown (rejected in design.md), the mic changes (`warm-mic`).

## Capabilities

### Modified Capabilities
- `talk-screen`: the pending Question bubble with countdown and editor; the keyboard button and typed Questions.
- `voice-loop`: the countdown stage between STT and the agent, typed Questions, cancelled Questions not stored, `confirm_ms` and `typed` on the turn.

## Impact

- Changed: `lib/maya/conversation.ex`, `lib/maya/voice/turn.ex`, `lib/maya/voice/latency.ex`, `lib/maya_web/live/talk_live.ex`, `assets/js/talk_hook.js`, `assets/css/app.css`, `config/config.exs` (`:confirm_ms`), a migration adding `turns.confirm_ms` (integer) and `turns.typed` (boolean, default false), tests.
- No new dependencies. The voice loop gains one stage on the path to first sound (the countdown), by design.
