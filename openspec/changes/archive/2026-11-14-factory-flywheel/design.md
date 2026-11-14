# Design

## Context

Builders end at a merged PR (`factory:build` step 11). Evidence already exists per Issue: PR timestamps and CI runs (`gh`), the `factory:test` table and red gates in the PR body, the `factory:review` comment (blocking list), and Claude Code session transcripts under `~/.claude/projects/<project>/*.jsonl`. `main` is protected, so anything written to the repo needs a PR.

## Goals / Non-Goals

**Goals:** comparable numbers per Issue; one lesson per Issue; experiments that are kept only when the numbers improve.
**Non-Goals:** perfect metrics; tracking token cost; changing more than one thing per experiment.

## Decisions

- **Metrics per Issue** (one row in `~/maya-factory/metrics.csv`):
  `issue, pr, merged_at, estimate_h, lead_time_h` (first branch commit to merge), `first_pass_green` (first CI run on the PR passed), `ci_red_runs`, `gate_reds` (red rows in the factory:test table), `review_blockers` (count under "Blocking" in the factory:review comment), `permission_prompts` and `denied_calls` (best effort: count of permission-denied tool results in the builder transcript; blank if not found).
- **Raw data outside the repo** (`~/maya-factory/`), like the quiz log: no PR per retro, survives worktrees. Distilled lessons and experiments enter the repo only through `factory:improve` PRs, so the repo stays reviewed.
- **Retro file** `~/maya-factory/retros/<issue>.md`: the metrics row, what went well, what went wrong, one lesson as a rule ("Do X when Y, because Z"), and a candidate experiment.
- **Hill climbing** in `factory:improve`, every 5 new retros: compute the median of each metric over the last 5 vs the 5 before; pick the worst moving metric; propose ONE change with a hypothesis ("allowing `git push` for feature branches cuts permission_prompts from 6 to 2"); open `chore(factory): experiment E<n> ...` PR that also appends to `docs/factory/experiments.md` (id, change, metric, baseline, target, status). After the next 5 retros: improved means keep (status `kept`), not improved means a revert PR (status `reverted`). Also folds the period's lessons into LESSONS.md, deduplicated.
- **Recap** reads `gh` (merged PRs, open Issues, `blocked` label, last main CI), the local metrics and new lessons; prints under 15 lines; writes nothing.
- **LESSONS.md** is short (under 40 rules), grouped by station; `factory:build` reads it before planning.

## Risks / Trade-offs

- [5 Issues is a tiny sample, noise looks like signal] → medians, one change at a time, and an explicit keep or revert record.
- [Transcript parsing is brittle across Claude Code versions] → those two metrics are best effort and may be blank; the rest come from GitHub.
- [Local data is lost with the machine] → acceptable; LESSONS.md and experiments.md in the repo hold what matters.

## Migration Plan

Seed LESSONS.md from this session's lessons, then backfill one retro for #16 to prove the skill. No rollback needed beyond reverting the PR.
