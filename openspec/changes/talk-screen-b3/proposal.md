# Proposal

GitHub Issue: #66. Stacks on #65 (guest sessions).

## Why

The Talk screen still opens with the old hero (Poke Ball, a second "Maya" heading, tagline) and a plain list of every turn. It does not show where the Guest is, who is on their Team or what the Next gym is, and nothing on screen changes while Maya listens, thinks or speaks except the button text. Abhishek picked layout B3 ("rich trainer card") from the mockups: a game HUD card at the top that shrinks while the Guest talks, a ring on Maya's ball per moment, a short chat and a Talk button pinned in the thumb zone.

## What Changes

- A trainer card at the top (`#trainer-card`): Maya's Emerald ball with a state ring, the Guest's location, the Next gym with its type chip (`#next-gym`), the Guest's Team with type dots and levels (`#team`), 8 badge slots and "N of 8 badges" (`#badge-count`), all from the Guest's Progress and game data, never past the Next gym.
- The screen root (`#talk-screen`) carries the Talk moment in `data-state`, mirrored from the Talk hook, so CSS drives the card shrink, the ring (coral pulse, gold spin, green glow), the sound wave and an aria-live status line (`#talk-status`). Reduced motion turns the animation off.
- Chat (`#turns`, list `#conversation`): the Guest's lines right, Maya's left, the latest Answer largest, only the last 3 exchanges, older ones faded, "(nothing heard)" as a friendly line.
- The Talk button is pinned at the bottom (safe-area aware, at least 44 px), with an inline SVG mic and one label per moment ("Hold to talk", "Release to send", "One sec…", "Hold to cut in") plus a hint line (`#talk-hint`).
- The hero, the second "Maya" heading, the tagline and the Mudkip hype line leave the Talk screen; the page keeps one visually hidden `h1`. Start fresh stays below the chat.

Out of scope: rotating catchphrases (#56), new game data, a demo GIF, live transcription while talking. New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `talk-screen`: the trainer card, the Talk moment on the root, the short chat and the pinned Talk button.
- `landing-page`: the hero, heading, tagline and Mudkip hype go; the Poke Ball moves into the card; the badge case shows the Guest's earned badges; the no spoilers rule allows the Next gym.

## Impact

- Changed: `lib/maya_web/live/talk_live.ex`, `assets/js/talk_hook.js` (one extra pushed event per state change), `assets/css/app.css`, the root layout viewport meta (`viewport-fit=cover` for the safe area), `test/maya_web/live/{talk_live,landing_page}_test.exs`, README if it describes the hero.
- No new dependencies, no new assets; the CSP is unchanged. The voice loop path is unchanged: the hook still plays audio on its own; the state push is fire and forget and only drives CSS.
