# Proposal

## Why

CI checks compile, format, credo and tests, but never the release image: the `SECRET_KEY_BASE` and `DATABASE_URL` failures only surfaced on Render, after merge. Nothing confirms a deploy actually went live, and one serial job hides which gate failed. Hardening the pipeline now protects every block the factory builds next.

## What Changes

- Every PR builds the release Docker image and boots it; a release that cannot start fails the PR.
- CI splits into parallel jobs (format, credo, test, docker, security) behind one aggregate `ci-success` check.
- **BREAKING (repo settings):** branch protection requires `ci-success` instead of `test`. Abhishek switches it once the new check exists.
- Security scans on every PR: known-vulnerable dependencies (`mix_audit`) and high-confidence Phoenix security findings (`sobelow`). Both are new dev and test dependencies, CI only.
- The test job measures line coverage with the built-in `mix test --cover`; the PR fails when total coverage of app modules falls below the threshold in `mix.exs`. Test support (`Maya.DataCase`, `MayaWeb.ConnCase`) and release-only `Maya.Release` are excluded. The threshold starts at the measured value rounded down and is only ever raised.
- Browser pages send a strict Content-Security-Policy (own origin only, the one inline theme script allowed by its sha256 hash, no framing), fixing sobelow's high-confidence `Config.CSP` finding.
- New `GET /health/version` returns the commit Render is serving (`RENDER_GIT_COMMIT`).
- After every push to `main`, a smoke check waits until `/health/version` reports that commit, checks `/` and `/health`, and opens an Issue labelled `bug` when the deploy does not go live or the checks fail.
- Out of scope: preview environments, dialyzer, deploy hooks, release tagging (release-manager), latency checks.

## Capabilities

### New Capabilities
- `delivery-pipeline`: what must pass before code merges and what is checked after it deploys.
- `service-health`: the endpoints that report the service is alive and which version is live.
- `web-security`: what browsers may load and run on Maya's pages.

### Modified Capabilities
None.

## Impact

- `.github/workflows/ci.yml` (split jobs), new `.github/workflows/post-deploy.yml`.
- `mix.exs`, `mix.lock`: `mix_audit`, `sobelow` (only: [:dev, :test]); `test_coverage` threshold and ignores.
- `lib/maya_web/router.ex` (CSP in the browser pipeline), `lib/maya_web/controllers/health_controller.ex`, their tests.
- GitHub branch protection (required check), FACTORY.md, ADR-001 guardrails, `factory:test`, `render-deploy` skill: mention `ci-success`.
