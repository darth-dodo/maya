# Tasks: team-edit

Two build PRs (3h in all, so split): C is the editor (2h), D is the PC box view and browser evidence (1h). C starts after `team-voice` PR A and #159 merge; D after C. D archives the change.

## 1. Editor (PR C, 2h)

- [x] 1.1 Chips as buttons with "Edit <name> Lv <level>", the `editing` assign, `#team-editor` with heading, Close, Escape, focus in and back, idle-only open and close on hold. Verify: `test/maya_web/live/talk_live_test.exs` tests for "Open the editor", "Close the editor", "Not while talking"; existing trainer card tests pass unchanged.
- [x] 1.2 Save level, Set as lead, Move to PC box and Remove through `Maya.Events.log/3` with `slot`, the live confirm line and Undo. Verify: tests for "Change a level", "Level out of range", "Set as lead", "Move to the PC box", "Remove", "Undo", "The last Team member", "Same result as voice".
- [x] 1.3 CSS in the Talk block: fixed overlay, 44px controls, `--maya-*` tokens only, no motion under reduced motion. Verify: `mix test test/maya_web/colour_gate_test.exs test/maya_web/design_tokens_test.exs`; `git diff --quiet origin/main -- assets/js/talk_hook.js`.

## 2. PC box and evidence (PR D, 1h)

- [x] 2.1 PC box list with Withdraw buttons and the empty line. Verify: tests for "View and withdraw", "Withdraw with a full Team", "Empty PC box".
- [x] 2.2 Playwright at 375x667 in both themes: control heights and names, no sideways scroll, band and button heights with and without the editor, reduced motion, the Team summary open while editing. Verify: computed values for "Targets and labels", "Steady band", "Both themes on tokens", "With the Team summary" in PR D.
- [ ] 2.3 Screenshots of the editor and PC box in both themes; `Phone check:` line from a real phone (E4). Verify: in PR D's body.

## 3. Docs

- [x] 3.1 Changelog fragment per PR. Verify: `openspec validate --all --strict`, `mix precommit` and `mix credo` green.

## Workflow follow-up

- Archive with `openspec-archive-change team-edit` in PR D.
