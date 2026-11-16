# Proposal: tide-talk

## Why

#130 (design-apply) put the tokens on the Talk screen, but it still has a full trainer card that shrinks between moments and a bubble chat. On 2026-11-15 Abhishek picked direction "A Tide" from the mocks canvas (https://claude.ai/artifact/MVn8DqEgNg2Mo3mmgx9nPf, board "A Tide: Talk"): a quiet header and an unboxed conversation, so the latest Answer reads like a page and the Talk button is easy to hit. This change covers the Talk screen. Its sibling is `tide-homepage`.

## What Changes

Talk screen `/talk`, presentation only:

- **Slim header** over faint tide art, or night art at night. It holds an eyebrow with the place and badge count, "Next gym: <leader>" in Fraunces with its type chip, the Team as wrapping chips, the ball and the badge case. It keeps one height in every moment, which replaces the shrink to a strip during `uploading` and `waiting`.
- **Unboxed conversation**: older Questions and Answers in `--maya-muted` at body size, the latest Answer as the largest text (about 24px) with no bubble, and a hairline between turns. Questions stay on the right.
- **Talk button** as a full-width pill, 72px tall, pinned at the bottom.

All behaviour stays as it is: the hold to talk state machine and its colours (coral recording, gold waiting, green speaking ring), the sticky header, Start fresh, live words, the voice down note and Poké facts. "Edit before send" and "Type instead" belong to #95 (`transcript-edit`). If #95 ships first, this restyle places its `#type-button` as a "Type instead" text link under the pill. If not, #95 follows the same placement. Either way this change adds no typing behaviour.

Out of scope: any behaviour, copy or state machine change, the homepage (`tide-homepage`), new tokens and a theme switch. New ideas go to PHASE_2.md.

Builds on #130 (merged 2026-11-15 as 5416f53). The build Issue starts from that main.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `talk-screen`: the trainer card becomes a slim header of fixed height over faint tide art, the short chat is unboxed with a hairline between turns, and the Talk button is a 72px full-width pill.

## Impact

- `lib/maya_web/live/talk_live.ex` (markup classes and order in `render/1`, no new assigns or events), `assets/css/app.css` (Talk block). `assets/js/talk_hook.js` is not expected to change.
- Tests: `talk_screen_page_test.exs` gains the new layout scenarios. Every existing `talk_live_test.exs` assertion about states, mic and the voice loop passes unedited.
- Voice loop: there is no server or hook change, so latency should not move. The PR still shows per-stage p50 from 5 phone holds before and after, because `talk_live.ex` and `app.css` are on the E4 phone check list.
- Issue: filed by `factory:plan` and linked from the spec PR.
