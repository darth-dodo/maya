# Proposal: team-collapse

## Why

Asked by Abhishek on 2026-11-16: "Make the Pokémon list collapsible". The sticky trainer band is about 203px tall at 375x667, 30% of the screen, and most of it is Team chips: a full Team wraps into rows that push the chat down on every Talk screen view. Folding the Team into one line gives the chat its room back without hiding the Team. Size: 1h.

## What Changes

The calls below are proposals Abhishek can correct on the spec PR.

- **Collapsed by default**: the Team in the trainer band shows as one summary line with a chevron. Abhishek chose option D on 2026-11-16: Team names in Team order, no levels, up to the first 3 comma separated, then "+N" for the rest ("Mudkip, Poochyena, Wingull +3"); 3 or fewer show all names with no "+N"; an empty Team reads "No Team yet".
- **One line on any phone**: if the names do not fit, they truncate with an ellipsis; the "+N" and the chevron always stay visible. The summary's accessible name lists the whole Team ("Team: Mudkip, Poochyena, Wingull, Ralts, Zigzagoon, Lotad").
- **Tap to open and close**: a tap on the summary shows the full Team as chips (as today); another tap folds it back.
- **State survives updates**: once open, the list stays open through any LiveView update (a catch while open keeps it open) for the rest of the page view; each visit starts collapsed, nothing is stored.
- **Updates never open it**: a new Team member updates the summary names and, when open, the chips; it never opens the list by itself.
- **Steady band**: the band and the Talk button keep the same size in every Talk moment (#74), open or closed; only the Guest's own tap changes the band height.
- **Accessible and on the design system**: a 44px tap target, native expanded and collapsed state for screen readers, both themes, only `--maya-*` tokens, no animated height (the chevron turn uses `--maya-duration`, 0ms under reduced motion), and `assets/js/talk_hook.js` untouched.

Out of scope: remembering the open state across reloads (would need browser storage), collapsing the badge case or the gym line, reordering the Team, any new Team data. New ideas go to PHASE_2.md.

Sequencing: two builders are working on #89 (trainer band refresh after Events, `talk_live.ex`) and #116 (Events). The build starts only after #89 merges, to avoid conflicts in the band markup, and its "a catch while open" check relies on #89's refresh.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `talk-screen`: a collapsible Team in the trainer band, with its summary line, open state and steady height.

## Impact

- Code: `lib/maya_web/live/talk_live.ex` (the `#team` markup inside the band), the Talk block of `assets/css/app.css`. No new dependency, no JS file, no server event.
- Tests: `test/maya_web/live/talk_live_test.exs` (one test per scenario), Playwright computed checks at 375x667 in both themes.
- Voice loop: not touched; the Talk button and `talk_hook.js` do not change.
- Issue: to be filed after the spec PR (factory:plan step 6).
