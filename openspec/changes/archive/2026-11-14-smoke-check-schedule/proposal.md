# Proposal

## Why

The post-deploy smoke check runs on every push to `main` and waits up to 20 minutes for `/health/version` to report the pushed commit. Render's `autoDeployTrigger: checksPass` waits for every GitHub check on that commit to finish before it deploys, and the smoke check is one of those checks. Render waits for the smoke check while the smoke check waits for Render: a deadlock. Evidence: on `b8fe17c` CI finished green at 17:19, the smoke run stayed in progress, and the live `/health/version` still answered "Not Found" (the previous build).

## What Changes

- The smoke check runs on a schedule (every 15 minutes) and on manual dispatch, never on push, so it is never a check on the commit Render is waiting to deploy.
- Each run compares the live `/health/version` with the head of `main`. If they match it checks `/` and `/health`. If they differ and the head commit is older than 20 minutes, the deploy is reported as not live. A younger head is a deploy in progress and is left alone.
- A problem opens one Issue labelled `bug` per commit; an open Issue for that commit stops a duplicate.
- The job always exits 0, so it can never fail a check or block a deploy.
- The logic moves into `scripts/smoke_check.sh` with a local test, `scripts/smoke_check_test.sh`.
- Out of scope: Render deploy hooks or API polling, alerting outside GitHub Issues, closing Issues automatically when a later deploy goes live.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `delivery-pipeline`: "Post-deploy smoke check" runs on a schedule against the head of `main` instead of after each push, dedupes Issues per commit, and never fails.

## Impact

- `.github/workflows/post-deploy.yml`: triggers and steps replaced.
- New `scripts/smoke_check.sh`, `scripts/smoke_check_test.sh`.
- `.claude/skills/render-deploy/SKILL.md`: files table, verify steps, failure table.
- No app code, no new dependencies, no new secrets (uses the workflow `GITHUB_TOKEN`).
