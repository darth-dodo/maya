# Design: team-collapse

## Context

The band markup is in `lib/maya_web/live/talk_live.ex`: `#team` is a `ul.card-team` spanning the full band grid (Issue 117), filled from `@card.team`. Today the card is read once on mount; #89 will refresh it after Events, so the band will start to re-render during a session. Phoenix LiveView is 1.2.13 (`mix.lock`).

## Goals / Non-Goals

Goals: the smallest change that folds the Team, with no JS file, no server round trip on tap and no new event. Non-goals: persisting the open state across reloads, animating the fold.

## Decisions

### Native `<details>`/`<summary>`, with `open` kept by `JS.ignore_attributes`

`#team` moves inside a `<details id="team-details">` whose `<summary id="team-summary">` holds the lead chip, the "+ K more" text and the chevron. The browser gives the expanded state, keyboard toggle and focus for free, and a tap toggles with no server round trip.

The catch: LiveView patches the DOM to match the server render, and the server never renders `open`, so a patch of the `<details>` (a Team change from #89) would close it. LiveView 1.1+ solves exactly this with `phx-mounted={JS.ignore_attributes(["open"])}`, which makes patches keep the client's `open` (https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html#ignore_attributes/1). It is a JS command in a `phx-` attribute, so the strict CSP and `talk_hook.js` are untouched.

Alternative considered: an `@team_open` assign toggled by `phx-click` on a button with `aria-expanded`. It survives patches by construction but costs a server round trip per tap, a new event and more markup. Fallback: if the builder's Playwright check shows `open` reset after an update despite `ignore_attributes`, switch to the assign and say why in the PR.

### No height animation

The open list simply appears; only the chevron turns, with `--maya-duration` (0ms under reduced motion). Animating `<details>` height needs JS or `interpolate-size`, which is not worth it here.

### Summary text in the template

"Name Lv N + K more" is built in the template from `@card.team`, so a Team change from #89 updates it in the same render. The lead is the first Team member, as listed in Progress.

## Risks / Trade-offs

- [Open Team grows the sticky band while the chat sits under it] → only on the Guest's own tap; the Talk button is pinned at the bottom, so nothing moves under a held finger (#74).
- [A Team change while open adds a chip row] → happens after a turn's Event, not during a hold; the Talk button does not move.
- [Hidden chips still in the DOM] → intended: existing tests that read `#team .mon` keep passing.

## Migration Plan

None: markup and CSS only. Rollback is reverting the PR.
