---
name: factory:dashboard
description: Use when Abhishek asks to see the factory, a dashboard, or "what needs me". Rebuilds one private page from live sources each run (GitHub, CI, the live app, ~/maya-factory/metrics.csv, experiments.md), "Needs Abhishek" first; writes nothing to the repo or GitHub.
---

# factory:dashboard

The visual version of `factory:recap` (spec: `openspec/specs/factory-dashboard/`). Read only: never write a comment, label, Issue, commit or repo file. Gather fresh every run; never reuse numbers from an earlier page.

## 1. Gather (in parallel, note the time of each read)

| Panel | Command or file |
|---|---|
| Open PRs and CI | `gh pr list --state open --json number,title,headRefName,isDraft,statusCheckRollup,reviewDecision` |
| Open Issues | `gh issue list --state open --limit 100 --json number,title,labels,milestone` |
| Board | `gh project item-list 1 --owner darth-dodo --format json --limit 200` (Status, Estimate per item) |
| Merged per day | `gh pr list --state merged --limit 100 --json number,mergedAt`, counted per day for the last 7 days |
| Main CI | `gh run list --branch main --workflow CI --limit 1 --json databaseId,conclusion,createdAt,url` |
| Smoke (E3) | `gh run list --workflow "Post-deploy smoke check" --limit 3 --json databaseId,conclusion,status,createdAt,url`, then `gh run view <id> --log` and keep only lines matching `ok:`, `problem:`, `skip`, `deploy in progress` and the HTTP code of `Question ->` |
| Missing secrets | `skip Question: SMOKE_TOKEN is not set` in the smoke log; a token error in the `codecov/codecov-action` step of the main CI log (`gh run view <id> --log \| grep -i codecov \| grep -i token`) |
| Deploy lag | `curl -s --max-time 10 https://maya-j56u.onrender.com/health/version` vs `git rev-parse origin/main` (after `git fetch origin`), and `git log --oneline <live>..origin/main` |
| Flywheel | `~/maya-factory/metrics.csv`: medians of `lead_time_h`, `ci_red_runs`, `review_blockers`, `denied_calls`, `review_precision`, share of `first_pass_green`, sums of `escaped_defects` and `review_misses`, last 5 rows vs the 5 before ("n/a" under 10 rows; skip empty cells) |
| Experiment | The `running` row of `docs/factory/experiments.md` (id, change, metric, baseline, target) |
| Running builders | `git worktree list`; a worktree on a branch with no PR (`gh pr list --head <branch> --state all`) is a running builder |

A failed command does not stop the page: its panel says what failed and the command, the rest still render.

## 2. Page order

1. **Needs Abhishek**: green PRs to merge (every check `SUCCESS`, not draft), decisions waiting (Issues labelled `needs-info`, `ready-for-human`, or `paused` with open questions in the handoff), missing secrets (the secret's name and the run link, never a value), the latest smoke `problem:` line if any.
2. **Flow**: open PRs with CI state, open Issues by milestone and label, board Status and Estimate counts, merged PRs per day (last 7 days), deploy lag (live SHA, `origin/main`, commits between), running builders.
3. **Quality**: the flywheel trend, last 5 vs previous 5, with the direction of each metric.
4. **Experiment**: the running row and its target.

Every number shows its source (command or file) and the read time, for example `3 (gh pr list, 21:40)`. Name the page "Maya factory". Inclusive language, "Pokémon" with é, no em or en dashes.

## 3. Publish

Write the gathered rows to a scratch file (never in the repo) as `{"rows": [...], "meta": [...]}`, one row per line on the page: `panel` (`needs`, `flow`, `quality` or `experiment`), `item` (unique), `value`, `detail`, `source`, `read_at`.

1. **Rerun** (`~/maya-factory/dashboard-url` holds a URL): upload the new JSON to that Artifact (`asset: true`), point `datasets/factory` at the new `/_blob/<id>` with `updated.at` set to now (ArtifactData `update`), then delete the old blob. The page is already there; leave `files/index.html` alone.
2. **First run**: if the Artifact tool's `quickstart` (intent `other`) lists the Data type, start from it with the title "Maya factory", follow its instructions to write `dash/meta`, `datasets/factory` (a `file` source, `fixed: true`) and `files/index.html` (four tables in the page order, `data-source="factory"`, `data-row-key="item"`), and save the URL to `~/maya-factory/dashboard-url`.
3. **No Artifact tool or no Data type**: write one HTML page from the same rows under `mktemp -d`, run `open <file>`, print the path.

Print the URL or path and the "Needs Abhishek" items as the reply.

## Never include

Secret values, `.env` contents, transcripts, Questions or Answers text, Guest ids, cookies, or anything from `gh secret`. Never open `.env`.
