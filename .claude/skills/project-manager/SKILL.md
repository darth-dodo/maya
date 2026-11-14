---
name: project-manager
description: Use when planning or reviewing the MAYA plan as a whole: turning PRODUCT.md or ARCHITECTURE.md into GitHub Issues, checking progress against the weekend plan and estimates, proposing cuts, triaging new ideas, or writing a status report
---

# Project manager

Owns the plan, not the code. Picking the single next task is the `next-task` skill. Cutting a version is `release-manager`.

Sources of truth: `FACTORY.md` (weekend plan, guardrails), `CLAUDE.md` (rules, cut order), GitHub Issues and milestones (work queue), `PHASE_2.md` (deferred ideas).

## Issues

Every Issue body has:

```markdown
## Goal
One sentence.

## Done when
- [ ] Checkable item, with how it is verified

## Estimate
30m | 1h | 2h

## Out of scope
```

- Voice loop Issues add a "done when" with per-stage latency numbers and the `voice-loop` label.
- One milestone per MAYA block (`Block 1: ...`).
- Draft the full list first and show it to Abhishek. Create Issues, labels and milestones only after his yes: `gh issue create --title ... --body-file ... --milestone ... --label ...`.

## Progress check

- Open work: `gh issue list --state open --json number,title,milestone,labels` and `gh pr list --state open`.
- Elapsed per in-progress Issue: time since the first commit on its branch (`git log --reverse --format=%cI origin/main..<branch> | head -1`).
- Past 2x estimate: propose the cut. F1 past 3h: the kill switch in `FACTORY.md` applies.
- More than 2 builders active: stop one.

## Cuts

- Order: Telegram digest, Herdr watcher, embeddings, journal, dials.
- Propose the cut with the reason. Abhishek decides.
- Once he agrees: close the Issue with a comment, add the `cut` label, and add one dated line to `PHASE_2.md`.

## New ideas

One dated line in `PHASE_2.md`. Never a new MVP Issue unless Abhishek asks for one.

## Status report

Also stands in for the 21:00 Telegram digest if that gets cut. Keep it under 10 lines:

1. Merged today (PR numbers and titles)
2. Open Issues per milestone, and anything blocked
3. CI failures on main
4. Time spent vs the weekend plan, and any proposed cut
5. Next 1 to 3 Issues
6. Gym reminder: at least one gym per build day
