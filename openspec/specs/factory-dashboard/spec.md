# factory-dashboard Specification

## Purpose
How the factory shows its own state on demand through `factory:dashboard`: the live sources it reads, the page order with Needs Abhishek first, the source and time on every number, where the page is published and what it never includes.

## Requirements

### Requirement: One command builds the dashboard from live sources

`factory:dashboard` SHALL gather, read only, at run time: open PRs with CI state, open Issues by milestone and label, Project 1 Status and Estimate, merged PRs per day, main's latest CI run, the latest post-deploy smoke check (E3 probe), `/health/version` against `origin/main`, `~/maya-factory/metrics.csv`, the running experiment in `docs/factory/experiments.md`, and running builders (worktrees on a branch with no PR). It SHALL write no comment, label, commit or repo file.

#### Scenario: Fresh data each run
- **WHEN** Abhishek runs `factory:dashboard` twice with a PR merged in between
- **THEN** the second page shows the merge; nothing is read from an earlier page

#### Scenario: Read only
- **WHEN** a run finishes
- **THEN** `git status` is unchanged and no GitHub comment, label or Issue was created

#### Scenario: Source unavailable
- **WHEN** one source fails (for example `gh project item-list` without the `project` scope, or the live app times out)
- **THEN** its panel shows the failure and the command that failed, and the other panels still render

### Requirement: Needs Abhishek comes first and every number is sourced

The page SHALL open with a "Needs Abhishek" panel (green PRs to merge, decisions waiting: Issues labelled `needs-info`, `ready-for-human` or `paused` with open questions, and missing secrets seen in CI), then flow (PRs, Issues, board, merges per day, deploy lag, running builders), quality (metrics trend, last 5 vs previous 5) and the running experiment with its target. Every number SHALL show its source command or file and the time it was read.

#### Scenario: Green PR waiting
- **WHEN** an open PR has every check green
- **THEN** it is listed first under "Needs Abhishek" as ready to merge

#### Scenario: Deploy lag
- **WHEN** `/health/version` reports a SHA other than `origin/main`
- **THEN** the flow panel shows both SHAs and the commits between them

#### Scenario: Trend
- **WHEN** `metrics.csv` has at least 10 rows
- **THEN** quality shows medians of `lead_time_h`, `ci_red_runs`, `review_blockers`, `denied_calls`, `review_precision`, the share of `first_pass_green` and the sum of `escaped_defects` and `review_misses`, last 5 vs previous 5; with fewer rows it shows "n/a"

### Requirement: Published privately, replaced on rerun, never committed

The page SHALL be published as a private claude.ai page from the Data Artifact type when the session offers it, else as an HTML file in a fresh temp folder opened in the browser. A rerun SHALL replace the same page, using the URL kept in `~/maya-factory/dashboard-url`. No dashboard file SHALL be added to the repo.

#### Scenario: Rerun
- **WHEN** `~/maya-factory/dashboard-url` holds a URL
- **THEN** the run publishes to that URL and prints it

#### Scenario: No Artifact tool
- **WHEN** the session has no Artifact tool or no Data type
- **THEN** the page is written under `mktemp -d`, opened with `open`, and its path printed

### Requirement: Never includes secrets or private data

The page SHALL NOT include secret values, `.env` contents, transcripts, Answers, Guest ids or cookies. A missing secret SHALL appear only as the name of the CI step that needed it and its outcome.

#### Scenario: Missing smoke token
- **WHEN** the latest post-deploy run skipped or failed the smoke step for lack of `SMOKE_TOKEN`
- **THEN** "Needs Abhishek" names `SMOKE_TOKEN` and links the run, with no value shown

### Requirement: Recap and next-task point to it

`factory:recap` and `next-task` SHALL mention `factory:dashboard` as the visual version, and FACTORY.md "Skills by station" and the CLAUDE.md factory entry points SHALL list it.

#### Scenario: Docs
- **WHEN** `grep -l "factory:dashboard"` runs over FACTORY.md, CLAUDE.md and both skills
- **THEN** all four files match
