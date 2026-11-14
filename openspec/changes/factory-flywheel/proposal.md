# Proposal

## Why

Every session so far taught the factory something (DATABASE_URL pitfalls, `| tail` hiding exit codes, the skipped Issue step, `skillOverrides` ignoring plugins), but the lessons live only in chat. Without measurement there is no way to tell whether a skill edit made the factory better. A flywheel turns each merged PR into data, and the data into small, tested improvements.

## What Changes

- New `factory:retro <pr>`: after a merge, records metrics for that Issue plus one lesson. Raw data lives outside the repo in `~/maya-factory/` (no PR per retro); `factory:build` step 11 runs it.
- New `factory:improve`: every 5 retros, reads the metrics, picks the worst one, and opens ONE experiment PR (a skill, allowlist or CI edit) with a hypothesis and a target. After the next 5 retros it compares and keeps or reverts the change (hill climbing).
- New `factory:recap`: on demand, summarises a session or day: merged PRs, open Issues and blockers, metric trend, new lessons, gym reminder. Stands in for the 21:00 digest moved to PHASE_2.md.
- New `docs/factory/LESSONS.md` (seeded with today's lessons) and `docs/factory/experiments.md`, updated only through `factory:improve` PRs. `factory:build` reads LESSONS.md at step 4.
- Out of scope: dashboards, hosted analytics, automatic skill edits without a PR, any app code.

## Capabilities

### New Capabilities
None: factory tooling and docs only, no app behaviour (`skip_specs: true`).

### Modified Capabilities
None.

## Impact

- New `.claude/skills/factory-retro/`, `factory-improve/`, `factory-recap/`.
- `.claude/skills/factory-build/SKILL.md` (read LESSONS.md at step 4, run `factory:retro` at step 11).
- New `docs/factory/LESSONS.md`, `docs/factory/experiments.md`; FACTORY.md "Skills by station" and a "Flywheel" section; CLAUDE.md skill list.
- Local, untracked: `~/maya-factory/retros/<issue>.md`, `~/maya-factory/metrics.csv`.
