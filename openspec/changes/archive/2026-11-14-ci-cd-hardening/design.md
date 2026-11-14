# Design

## Context

CI is one serial `test` job (`.github/workflows/ci.yml`), required by branch protection. Render deploys main only after checks pass (`autoDeployTrigger: checksPass`). Render sets `RENDER_GIT_COMMIT` at runtime (https://render.com/docs/environment-variables). `/health` exists and skips the database.

## Goals / Non-Goals

**Goals:** catch release breaks on the PR; one stable required check; detect a deploy that never goes live.
**Non-Goals:** blue/green or rollback automation; scanning beyond deps and Phoenix code.

## Decisions

- **Aggregate `ci-success` job** (`needs:` all jobs, `if: always()`, fails unless every result is `success`). Alternative: require each job in branch protection; rejected because every new job would need a settings change.
- **Docker job:** `docker build`, then run the image with `PORT`, a generated `SECRET_KEY_BASE` and an unreachable `DATABASE_URL`, and poll `/health` for up to 60 s. Proves boot and config without a database, the same smoke test as the `render-deploy` skill. Alternative: `mix release` only; rejected, it skips the Dockerfile and runtime config.
- **Coverage:** built-in `mix test --cover` with `test_coverage: [summary: [threshold: N], ignore_modules: [Maya.DataCase, MayaWeb.ConnCase, Maya.Release]]` in `mix.exs`; N is the measured total after the ignores, rounded down. Ratchet: raise N whenever a PR raises total coverage by 5 points or more; never lower it. Alternative: ExCoveralls; rejected, it is a new dependency and its extra value is hosted reports and badges.
- **Security:** `mix deps.audit` (`mix_audit`) and `mix sobelow --exit high`; dev/test only, so nothing ships to the release. Medium and low sobelow findings are printed, not failed, to avoid noise from generator defaults.
- **CSP:** `put_secure_browser_headers` in the browser pipeline gets a literal policy: `default-src 'self'; script-src 'self' 'sha256-<theme script>'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'`. A hash, not a nonce, keeps the policy a compile-time literal (sobelow can see it) and needs no per-request plug. Inline styles stay allowed: LiveView and topbar set style attributes, and heroicons are `data:` masks. A test recomputes the hash of every inline script on the rendered page, so editing the theme script without updating the policy fails CI. Alternatives: `'unsafe-inline'` scripts (rejected, defeats the point) or a nonce plug (rejected, more code for one static script).
- **Version endpoint:** `/health/version` in the same no-pipeline scope as `/health`, reading `RENDER_GIT_COMMIT` at request time, defaulting to `unknown`. Keeps `/health` exactly `ok` for Render's health check. Alternative: put the SHA in `/health`; rejected, it changes the liveness contract.
- **Post-deploy workflow** on `push` to main: poll `https://maya-j56u.onrender.com/health/version` every 30 s for up to 20 min until it equals `$GITHUB_SHA`, then curl `/` and `/health`. On failure open an Issue with `gh issue create --label bug` using `GITHUB_TOKEN` (`permissions: issues: write`). Alternative: GitHub `deployment_status` events; rejected, Render's reporting of them is not verified and polling needs no integration.
- **Required check switch:** after this PR shows `ci-success` green, Abhishek updates branch protection from `test` to `ci-success`. Until then `test` still exists as a job name, so nothing blocks.

## Risks / Trade-offs

- [Docker build adds minutes to every PR] → cache layers with `docker/build-push-action` and the GitHub Actions cache.
- [Generated `MayaWeb.CoreComponents` (17% at baseline) keeps the total low] → the floor starts low and climbs with each feature's tests; do not ignore it, Maya will use those components.
- [sobelow flags generator code] → fail only on high confidence; record any suppression with a one-line reason.
- [A merge that does not deploy (Render skips) waits 20 min and opens a false Issue] → the Issue body says "check Render events"; acceptable at this volume.
- [Two merges in quick succession: the first smoke run sees the second SHA] → concurrency group on the workflow cancels the older run.

## Migration Plan

Merge with `test` still required; confirm `ci-success` green on the PR; switch the required check; update docs that name `test`. Rollback: revert the PR and switch the required check back to `test`.
