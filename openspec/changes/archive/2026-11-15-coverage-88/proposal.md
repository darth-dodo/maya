# Proposal

## Why

Line coverage was 67.51% on main (CI run 43648504894) with the floor at 67. Most of the gap was generator code: `MayaWeb.CoreComponents` at 17%, an unused `Maya.Mailer` with its Swoosh config, and an unused `DNSCluster` child. Coverage is also only visible in the CI log; habla-hermano shows it on Codecov with a README badge.

## What Changes

- Remove unused generator code: `Maya.Mailer`, Swoosh (dep, config, dev mailbox route) and DNSCluster (dep, child, `DNS_CLUSTER_QUERY` config).
- Add tests for the core components (flash, button, input types, header, table, list, JS helpers, error translation) and for `mix maya.import`.
- Raise the coverage floor to the measured total rounded down.
- `mix test --cover` also writes `cover/lcov.info` (LCOV) with no new dependency, and CI uploads it to Codecov. An upload error or a missing `CODECOV_TOKEN` never fails CI.
- Codecov badge at the top of README.md.
- Out of scope: voice-loop browser tests, tests for `mix maya.fetch_data` (network task run by hand), the README rewrite (#51), Codecov PR comments or status checks.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `delivery-pipeline`: "Test coverage floor" also produces a coverage report Codecov reads and uploads it without ever failing the pipeline on an upload error.

## Impact

- `mix.exs` (threshold, coverage tool, two deps removed), `mix.lock`, `config/*.exs`, `lib/maya/application.ex`, `lib/maya_web/router.ex`, `lib/maya/mailer.ex` (deleted).
- New `test/support/lcov_coverage.ex`, tests under `test/maya_web/components/`, `test/maya/`, `test/mix/`.
- `.github/workflows/ci.yml`: one Codecov upload step in the test job.
- New secret: `CODECOV_TOKEN` (GitHub Actions, added by Abhishek). No runtime secrets change.
