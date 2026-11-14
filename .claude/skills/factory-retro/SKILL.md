---
name: factory:retro
description: Use after a Maya PR merges (factory:build step 11), or when backfilling one, to record that Issue's metrics row and one lesson in ~/maya-factory/. Writes nothing in the repo.
---

# factory:retro

Flywheel step 1 (FACTORY.md "Flywheel"). Argument: a merged PR number. Raw data lives outside the repo, so a retro needs no PR:

- `~/maya-factory/metrics.csv`: one row per Issue. Create the folder and the file with the header below if missing.
- `~/maya-factory/retros/<issue>.md`: the retro file.

Rerunning for the same Issue replaces its row and file; never add a second row.

## 1. Gather

| Value | Source |
|---|---|
| PR facts | `gh pr view <pr> --json number,headRefName,mergedAt,closingIssuesReferences,commits,body,comments` |
| Issue and estimate | `gh issue view <issue> --json body` ("Estimate" section) |
| CI runs | `gh run list --branch <headRefName> --event pull_request --workflow CI --json conclusion,createdAt` (CI only; other workflows do not count) |
| Transcript | Lines of `~/.claude/projects/<project>/*.jsonl` (and `*/subagents/*.jsonl`) whose `cwd` is the builder's worktree, up to `mergedAt` |

## 2. Metrics row

Header (exact order): `issue,pr,merged_at,estimate_h,lead_time_h,first_pass_green,ci_red_runs,gate_reds,review_blockers,permission_prompts,denied_calls`

| Column | Rule |
|---|---|
| `issue` | First closing Issue number |
| `pr` | PR number |
| `merged_at` | `mergedAt`, ISO 8601 UTC |
| `estimate_h` | Issue estimate in hours (30m = 0.5) |
| `lead_time_h` | Earliest branch commit `committedDate` to `mergedAt`, hours, 2 decimals |
| `first_pass_green` | `true` if the oldest CI run on the PR concluded `success`, else `false` |
| `ci_red_runs` | CI runs on the PR with conclusion `failure` |
| `gate_reds` | Red gates in the PR body's `factory:test` evidence ("red", "failed", nonzero exit), counting each fixed red once |
| `review_blockers` | Items under "Blocking" in the `factory:review` PR comment; "None" is 0 |
| `permission_prompts` | Best effort: tool calls in the transcript window that waited on a human approval. Blank if the transcript does not show them |
| `denied_calls` | Best effort: `is_error` tool results in the window saying denied, refused or "too complex to verify". Blank if no transcript |

Blank means unknown, never 0. Never guess a number.

## 3. Retro file

```markdown
# Retro #<issue> (PR #<pr>)
<header line>
<metrics row>

## Went well
- ...
## Went wrong
- ...
## Lesson
Do X when Y, because Z. (#<pr>)
## Candidate experiment
One change, the metric it should move, and from what to what.
```

Ground every line in the gathered evidence (PR body, review comment, CI, transcript). One lesson only.

## 4. Report

Print the row and the lesson. If `metrics.csv` now has 5 rows merged after the `Last improve run` line in `docs/factory/experiments.md`, say that `factory:improve` is due.
