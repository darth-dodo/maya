# Tasks

## 1. Smoke check script (test first)

- [x] 1.1 Write `scripts/smoke_check_test.sh`: runs `scripts/smoke_check.sh` with `DRY_RUN=1` against the live site for (a) head equals the live version -> "ok", (b) head `deadbeef` committed 1 hour ago -> would open a "not live after 20 minutes" Issue, (c) head `deadbeef` committed now -> "deploy in progress", no Issue; each exits 0; verify it fails before the script exists
- [x] 1.2 Write `scripts/smoke_check.sh` (bash, shellcheck clean); verify the test passes

## 2. Workflow

- [x] 2.1 Replace the `push` trigger in `.github/workflows/post-deploy.yml` with `schedule` (every 15 minutes) and `workflow_dispatch`, running the script; verify with actionlint

## 3. Docs

- [x] 3.1 Update the `render-deploy` skill (files table, verify steps, failure table); verify `git grep -n "push to main"` finds no stale smoke check reference
- [x] 3.2 Run `factory:test`; verify all gates green

## Workflow follow-up

- After merge, trigger the workflow once with `gh workflow run post-deploy.yml` and confirm it reports `ok` for the merged commit.
