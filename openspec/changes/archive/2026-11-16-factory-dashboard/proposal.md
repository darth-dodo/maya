# Proposal

GitHub Issue: #104 (Kind factory, Estimate 1h). Factory idea from Abhishek on 2026-11-15.

## Why

The factory's state is spread over GitHub (PRs, Issues, Project 1, CI runs), the live app (`/health/version`), `~/maya-factory/metrics.csv` and `docs/factory/experiments.md`. `factory:recap` prints 14 lines of it as text; nothing shows it on one page with what needs Abhishek first. A stored dashboard would go stale, so the page must be rebuilt from live sources every time it is asked for.

## What Changes

- New project skill `factory-dashboard` (user-facing `factory:dashboard`), read only: a gather table (GitHub, CI, live app, flywheel, running builders), a page layout ("Needs Abhishek" first, then flow, quality and the running experiment), a publish step and a never-include list.
- Publishes a private claude.ai page from the Data (Dashboard) Artifact type when the session offers it, else a plain HTML file in a temp folder opened in the browser. Rerunning replaces the same page; its URL lives in `~/maya-factory/dashboard-url`, outside the repo.
- `factory:recap` and `next-task` point to it as the visual version.
- Docs: FACTORY.md "Skills by station" and the CLAUDE.md factory entry points list it.

Out of scope: a dashboard inside the Maya app, persistent metrics storage, alerts, a generator script. New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities
- `factory-dashboard`: how the factory shows its own state on demand: sources, page order, sourcing of every number, where it is published and what it never includes.

### Modified Capabilities

None.

## Impact

- New: `.claude/skills/factory-dashboard/SKILL.md`.
- Changed: `.claude/skills/factory-recap/SKILL.md`, `.claude/skills/next-task/SKILL.md`, FACTORY.md, CLAUDE.md.
- No app code, no new dependency, service or host (gh, git, curl and the Artifact tool only), nothing outside the frozen stack.
