# Proposal: team-edit

## Why

Decided by Abhishek on 2026-11-16: "Provide tools to update team" and "Voice + on-screen edit". Voice is the experience, but fixing a level or a lead by voice costs a full turn and an Answer, and a misheard name is easier to see than to hear. A small editor on the Team chips lets the Guest fix the Team in two taps, writing the same Events `team-voice` adds, so voice and screen never disagree.

## What Changes

- **Tap a Team chip to edit it**: each `.mon` chip in the trainer band becomes a real button that opens a small editor for that member, with: change level, set as lead, move to the PC box, and remove (`released`).
- **PC box in the editor**: a "PC box" button in the editor lists the PC box members (names and levels) with a Withdraw button each; the trainer card never lists the PC box members; the open Team list ends with a "PC box (N)" button into the same list (Abhishek, 2026-11-18: "I can't see the box").
- **Same Events, one writer**: every action calls `Maya.Events.log/3` with the `team-voice` kinds (`set_level`, `set_lead`, `deposited`, `released`, `withdrawn`) and the member's `slot`; there is no second Progress writer. The editor shows the confirm or refused line, and an Undo button logs `undo`.
- **Voice stays in charge**: the editor opens only while the Talk moment is idle and closes when a hold starts; it is an overlay, so the band and the Talk button never change size (#74). `assets/js/talk_hook.js` is untouched.
- **Accessible and on the design system**: real buttons with labels, at least 44px targets, focus moves into the editor and back to the chip, Escape and a Close button close it, both themes, only `--maya-*` tokens, no motion under reduced motion.
- **Works with `team-collapse`**: chips are reached by opening the collapsed Team summary (#159); the summary line updates after an edit and the open state is kept.

Out of scope: editing species or evolving from the screen, reordering beyond the lead, adding a new Pokémon from the screen (say it, or use `set_team` by voice), putting screen edits into the Conversation, a confirm dialog before remove (Undo covers it). New ideas go to PHASE_2.md.

Sequencing: builds after `team-voice` (the kinds and `slot`) and after #159 (`team-collapse`, same band markup). #160 (live band refresh) is merged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `talk-screen`: a Team editor opened from a Team chip, with a PC box view, writing Events.

## Impact

- Code: `lib/maya_web/live/talk_live.ex` (chip buttons, editor markup, `handle_event` clauses that call `Maya.Events.log/3`), the Talk block of `assets/css/app.css`. No new dependency, no new JS file, no migration.
- Tests: `test/maya_web/live/talk_live_test.exs` (one test per scenario); Playwright computed checks at 375x667 in both themes.
- Voice loop: not touched; the editor is idle-only and `talk_hook.js` has no diff.
- Issue: to be filed after the spec PR (factory:plan step 6).
