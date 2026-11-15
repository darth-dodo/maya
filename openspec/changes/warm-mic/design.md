# Design

## Context

See proposal.md, Why. Today `press()` calls `openMic()` (fresh `getUserMedia`, a `ScriptProcessorNode` of 4096 frames) and sets `this.recording = true` only after the promise resolves; `release()` calls `closeMic()`. Samples before the stream is live are lost by construction. The hold report already carries `mic_open_ms` (press to live), the direct measure of the lost audio on each press.

## Goals / Non-Goals

**Goals:** no lost first syllable on any press after the first in a turn sequence; mic indicator off within about 5 s of the last turn; no server latency change.

**Non-Goals:** fixing the very first cold press of a visit (the browser has no audio before `getUserMedia` resolves; the `recording` cue already tells the Guest when to speak); AudioWorklet; post-roll.

## Decisions

- **Keep the mic for the turn, not the visit.** Closing 4 s after idle keeps #79's goal (the mic was live for the whole page session before #81) while covering follow-ups and barge-in, which happen while Maya speaks. Alternative: keep it open for the page session; rejected, it undoes #79.
- **Pre-roll in the existing `onaudioprocess`.** While open and not held, blocks go into a ring capped at the pre-roll length (300 ms is 14,400 samples at 48 kHz); on press the ring is drained into `samples`. No new node, no new dependency. 300 ms covers a typical press-to-speech reaction overlap; configurable as a hook constant.
- **Echo cancellation stays on** (`echoCancellation: true` in today's constraints), so a barge-in pre-roll recorded while Maya speaks carries little of her voice.
- **Close on hidden.** `visibilitychange` to hidden closes at once: a phone in a pocket never keeps the mic.

## Risks / Trade-offs

- [The mic indicator stays on through the Answer] → by design; it goes off 4 s after idle, documented in the spec.
- [Pre-roll can catch Maya's last word on a barge-in] → echo cancellation; the countdown in `transcript-edit` lets the Guest fix it.
- [ScriptProcessorNode timing on phones] → unchanged from today; the existing shortcut comment stays.

## Migration Plan

Hook-only change; rollback is reverting the PR.
