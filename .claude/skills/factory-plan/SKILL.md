---
name: factory:plan
description: Use when planning a Maya block or feature into the factory work queue, from idea to OpenSpec change, spec PR and GitHub Issue. Runs the plan station in order so no step is skipped.
---

# factory:plan

Plan station (FACTORY.md line 2). Planning only: never edit app code here. Each step must meet its "done when" before the next starts. Invoke the named skills with the Skill tool; do not copy their content.

| # | Step | Use | Done when |
|---|---|---|---|
| 1 | Stack check | `settled-architecture` | Nothing outside the frozen stack, or Abhishek said yes and an ADR is planned |
| 2 | Branch | `git fetch origin && git checkout -b spec/<change-id> origin/main` | On the spec branch |
| 3 | Propose | `openspec-propose <change-id>: <what>` | proposal, specs and tasks exist; `design.md` only if its instruction applies |
| 4 | Validate | `openspec validate <change-id> --strict` | "is valid" |
| 5 | Spec PR | CHANGELOG line, commit, push, `gh pr create` titled `docs: propose <change-id> OpenSpec change` | PR open, CI green |
| 6 | Issue | `project-manager` Issue template: Goal, Spec (`openspec/changes/<change-id>/`), Done when (from the scenarios, plus "change archived in the same PR"), Estimate, Out of scope; labels `ready-for-agent`, `voice-loop` if it touches the voice loop; milestone for the block. Show the draft to Abhishek, create only after his yes | Issue #N exists |
| 7 | Link | Prepend `Part of #N` to the spec PR body | Spec PR and Issue link both ways |
| 8 | Stop | Report the PR and Issue links | Abhishek merges the spec PR; then a builder runs `factory:build #N` |

Never skip step 6: a change without an Issue is invisible to `next-task`.
