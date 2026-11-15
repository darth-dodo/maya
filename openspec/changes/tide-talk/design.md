# Design: tide-talk

## Context

After #130, `talk_live.ex` renders `#trainer-card` (ball, location, Next gym, badge case, badge count, Team), `#talk-status`, `#turns` with `#conversation`, Poké facts, Start fresh and the pinned `#talk-button`. The CSS shrinks the card to a strip while `uploading` and `waiting`. `talk_hook.js` owns the button's `data-state`. The tests in `talk_live_test.exs` and `talk_screen_page_test.exs` pin ids, classes, labels and states. #95 (`transcript-edit`) is open and will add `#type-button` and the countdown.

## Goals / Non-Goals

**Goals:** the Tide look in proposal.md, done with CSS and the order and classes of the markup only. Every existing id, class, label, aria attribute and event stays.

**Non-Goals:** changes to `talk_hook.js`, new assigns, events or copy, typing (#95), and new tokens.

## Decisions

1. **Restyle, do not rebuild.** Keep every id the tests and the hook use (`#trainer-card`, `#talk-button`, `#conversation`, `.turn.now`, `#live-question`, `#pending-question`, `#voice-down`, `#badge-case`, `#start-fresh-*`). The one new wrapper is `#card-eyebrow` around `#location` and `#badge-count`. This keeps the "Behaviour unchanged" scenario of the design system requirement true without edits, and keeps `talk_hook.js` out of the diff. Rebuilding the markup would put the E4 press path at risk for a visual change.
2. **Fixed header height instead of the strip.** The strip was there to keep the button still while the card changed. A slim header that never changes height does the same job more simply, so the shrink rules are deleted rather than tuned.
3. **Faint art via a scrim.** `#trainer-card` gets `background: linear-gradient(color-mix(in srgb, var(--maya-bg) 85%, transparent), color-mix(...)), url(/images/backdrops/tide.jpg)` on `:root`, and `night.jpg` in both night blocks. Text then sits on a background that is at least 85% `--maya-bg`, so the existing muted and ink on bg pairs hold. `color-mix()` has no literal, so the colour gate passes. Opacity on the text itself is ruled out by the design system.
4. **Unboxed turns.** The bubble backgrounds, borders and shadows on `.question` and `.answer` are removed. `.turn + .turn` gets `border-top: 1px solid var(--maya-line)`. Older turns use `--maya-muted` at `--maya-text-base`. `.turn.now .answer` uses `--maya-text-xl` (25px) in Inter with `--maya-ink`. Muted on bg is 5.38:1 by day and 9.61:1 at night, so it is not faded with opacity.
5. **72px pill.** `#talk-button` keeps its state colours and ring. Only its size (`height: 72px`, full width inside the 16px gutters) and radius change. `#talk-hint` stays inside. A "Type instead" slot is reserved under the pill: an empty wrapper is not added. #95 places its `#type-button` there as a text link at 44px.
6. **Gold hairline at night** moves to the header's bottom border, so the existing night scenario (card border colour) still holds.

## Risks / Trade-offs

- [A layout change makes a long press lose capture on iPhone (E4)] → no hook change, the button's box only grows; the phone check covers 5 holds and a cut-in.
- [Art behind the header hurts legibility on some phones] → the 85% scrim; screenshots in both themes at 375px; Abhishek's phone check.
- [#95 lands first and its markup conflicts] → the builder rebases onto it and places `#type-button` per decision 5; the specs do not overlap.

## Migration Plan

One PR. Roll back by reverting the squash commit; no data, route or event change.
