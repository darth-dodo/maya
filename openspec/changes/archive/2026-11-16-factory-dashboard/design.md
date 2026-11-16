# Design

## Context

See proposal.md (Why). Every source is already readable by a builder session: `gh` (PRs, Issues, runs, Project 1 `PVT_kwHOALocAs4Brni8`), `curl` for `/health/version`, and the local files `~/maya-factory/metrics.csv` and `docs/factory/experiments.md`.

## Goals / Non-Goals

Goals: one page, rebuilt from live sources on each run, "Needs Abhishek" first, every number with its source and time, nothing stored in the repo.

Non-Goals: a generator script, history across runs, alerts, a page inside the Maya app.

## Decisions

1. **A skill, not a script.** The `factory:*` stations are all markdown skills run by a session; a script would be code to test and keep in step with gh output. The skill names each command and the session renders the page. Alternative (a Mix task or shell script writing HTML) rejected: more code, same data.
2. **Publish target.** The Data Artifact type is built for "every number shows where it came from" and gives a private page. When a session lacks the Artifact tool or the type, the fallback is a plain HTML file under `mktemp -d`, opened with `open`. Either way no file lands in the repo.
3. **Rerun replaces.** The Artifact URL is kept in `~/maya-factory/dashboard-url` (the factory's local data folder, like `metrics.csv`); the next run publishes to that URL. No URL file means a first run.
4. **Missing secrets from CI, not from secrets.** A missing `CODECOV_TOKEN` or `SMOKE_TOKEN` shows only as the outcome of the step that needs it in the latest run. The skill never reads or prints secret values and never opens `.env`.

## Risks / Trade-offs

- A session renders the page by hand, so layouts can drift between runs. Mitigation: the skill fixes the section order and the "value, source, time" shape.
- Project 1 needs the `project` scope on the gh token. If `gh project item-list` fails, the board panel says so instead of failing the page.
