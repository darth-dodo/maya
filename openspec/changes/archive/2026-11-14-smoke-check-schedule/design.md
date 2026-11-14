# Design

## Context

`render.yaml` sets `autoDeployTrigger: checksPass`. Render then deploys a commit on `main` only after every GitHub check on it has completed, and deploys nothing if one fails (https://render.com/docs/deploys). A workflow triggered by `push` to `main` reports a check on that same commit, so a push-triggered smoke check that waits for the deploy can never see it.

## Goals / Non-Goals

**Goals:** detect a deploy that never went live and a live app that is broken, without the detector itself gating the deploy.

**Non-Goals:** exact per-commit timing, verifying commits that were superseded before they went live, auto-closing Issues.

## Decisions

- **Schedule plus manual dispatch, no push trigger.** Nothing waits for the deploy, so Render never waits on the smoke check. A scheduled run can still land as a check on the head commit while CI runs, but it finishes in seconds and always succeeds, so at worst it delays a deploy by that long. Rejected: keeping `push` with `exit 0` (Render still waits for the run to complete, delaying every deploy by up to 20 minutes and still racing the wait loop).
- **Check the head of `main`, judge by its commit time.** Head younger than 20 minutes and not live means a deploy in progress, not a problem. Older and not live means it never went live. The time is the committer date of the head commit from `gh api repos/darth-dodo/maya/commits/main`; for squash merges it is the merge time.
- **Always exit 0.** Problems are reported only as Issues; a red scheduled run would add noise and nothing more.
- **One Issue per commit.** The title carries the short SHA; an open Issue whose title contains it suppresses a new one, so a 15 minute schedule does not spam.
- **Logic in `scripts/smoke_check.sh`.** Testable locally with `DRY_RUN=1` and `SITE`, `HEAD_SHA`, `HEAD_TIME` overrides; the workflow only checks out and runs it.

## Risks / Trade-offs

- Up to 15 minutes (plus GitHub schedule delay) before a problem is noticed, instead of right after the deploy. Accepted: detection never worked before.
- GitHub disables scheduled workflows after 60 days without repository activity. Acceptable for an active repo; `workflow_dispatch` remains for manual runs.
- A commit superseded before it deploys is never checked; the newer head is.
