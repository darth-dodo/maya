---
name: next-task
description: Use at the start of a session, or after finishing a task, to decide what to work on next in Maya
---

# Next task

## 1. Gather (in parallel)

- `git status --short`, `git branch --show-current`, `git worktree list`
- `gh pr list --state open --json number,title,headRefName,statusCheckRollup,reviewDecision`
- `gh pr list --state merged --limit 5 --json number,title,closingIssuesReferences`
- `gh issue list --state open --json number,title,labels`

## 2. Rank (first match wins)

1. **Stale loops:** an Issue still open whose PR is merged. Check its "done when" against the live app (`curl -sI <render url>/health`), then close it with a link to the PR.
2. **Green PRs waiting for merge:** tell Abhishek. Never merge yourself; merging is the human gate.
3. **Uncommitted work** in any worktree: finish it or ask.
4. **Red PRs:** fix CI first (use superpowers:systematic-debugging).
5. **In progress:** an Issue with an open branch and no PR.
6. **New work:** the lowest numbered open Issue that has a "done when". No "done when" means ask, do not guess.

Limits: max 2 builders in parallel, one block at a time, stop at "done when".

## 3. Report

One recommendation with the reason, then the ranked list in one line per item.
