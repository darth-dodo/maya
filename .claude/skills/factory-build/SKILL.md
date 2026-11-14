---
name: factory:build
description: Use when a builder session implements a Maya GitHub Issue end to end, from picking it up to an open PR that meets the definition of done. Runs build and verify in order, calling factory:test and factory:review.
---

# factory:build

Build and verify stations (FACTORY.md lines 3 and 4). Argument: an Issue number, or none to let `next-task` pick. Invoke named skills with the Skill tool; do not copy their content. Each step must meet its "done when" before the next.

| # | Step | Use | Done when |
|---|---|---|---|
| 1 | Pick | `next-task` if no Issue given; `gh issue view <n>` | One Issue with a "done when" and a Spec link |
| 2 | Preconditions | Running in a worktree (`claude -w <issue>`), not on `main`; `openspec/changes/<change-id>/` exists on `origin/main` | Both true, else stop and say which |
| 3 | Branch | `git checkout -b <type>/<change-id>` from `origin/main` | On the feature branch |
| 4 | Read | The Issue, the change's `proposal.md`, `specs/`, `tasks.md`, then `docs/factory/LESSONS.md`; `settled-architecture` before adding anything new | Every scenario mapped to a planned test |
| 5 | Plan | `superpowers:writing-plans` from `tasks.md` | Short plan, one step per task |
| 6 | Build | `superpowers:test-driven-development` per task; tick each `tasks.md` checkbox when its verification passes | All build tasks ticked |
| 7 | Test | `factory:test` | All gates green |
| 8 | Archive | `openspec-archive-change <change-id>` | Change moved to `openspec/changes/archive/`, `openspec/specs/` updated |
| 9 | PR | Changelog fragment `changelog.d/<branch-with-dashes>.md`, PR template filled, `Closes #<n>`, Conventional Commit title; `superpowers:verification-before-completion` before claiming done | PR open, CI green |
| 10 | Review | `factory:review <pr>` | No blocking findings, or they are fixed and step 7 rerun |
| 11 | Stop | Report the PR link | Abhishek merges. Then run any post-merge task in `tasks.md`, comment the result on the Issue, and run `factory:retro <pr>` |

Denied, do not try: `openspec-apply-change`, Matt `tdd`, Matt `diagnosing-bugs` (use `superpowers:systematic-debugging`). Never merge, never push to `main`.
