# Proposal

GitHub Issue: #94 (part of #75, Block 7: Realtime transcription).

## Why

Since #81 (#79's privacy fix) every press opens a fresh mic, and samples count only once the stream is live. `getUserMedia` takes tens to hundreds of ms on a phone (the hold report's `mic_open_ms`), so a Guest who starts speaking as they press loses the first syllable or word. Batch STT then guesses from a clipped clip, which shows up as the transcription errors Abhishek reported on 2026-11-15 ("it's a poor experience now with a lot of transcription errors"). This is the fastest fix and needs no new service.

## What Changes

- The first press opens the mic; it then stays open while a turn is in flight (recording, uploading, waiting, speaking) and closes a few seconds (default 4 s) after the button is back to idle with no new press. The orange dot goes off within about 5 s of the last turn ending, so #79's privacy goal holds.
- While the mic is open between holds, the hook keeps only a short rolling pre-roll (default 300 ms) in memory and drops everything older. A press prepends the pre-roll, so the first syllable is never lost on a warm press.
- On a cold press (mic closed), behavior is as today: `recording` only once the stream is live.
- After release the hook keeps recording a short post-roll (default 150 ms, set by the button's `data-post-roll-ms`) so a clipped last word is kept. The button shows its sent state (`uploading`) at once; the clip uploads after the tail, so release to upload is about 150 ms later (added by Abhishek on 2026-11-15, "Yes catch all words").
- The hold report gains `warm: true|false` and `post_roll_ms`, so the Render log shows how many presses were warm and the tail each one recorded.

Out of scope: streaming audio and realtime STT (`realtime-transcription`), the transcript countdown and editor (`transcript-edit`), an AudioWorklet rewrite.

## Capabilities

### Modified Capabilities
- `talk-screen`: "Mic only while held" keeps its name but the mic now stays warm for the turn, with a pre-roll; "Hold end" logs warm presses.

## Impact

- Changed: `assets/js/talk_hook.js`, `lib/maya_web/live/talk_live.ex` (hold report field), `test/maya_web/live/talk_live_test.exs`, a node check for the pure ring buffer helpers.
- No new dependencies, no server voice loop change, no CSP change.
