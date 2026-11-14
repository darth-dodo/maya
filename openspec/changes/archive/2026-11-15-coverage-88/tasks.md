# Tasks

## 1. Remove unused generator code

- [x] 1.1 Grep for `Maya.Mailer`, `Swoosh` and `DNSCluster` callers; verify none outside config and the generator wiring
- [x] 1.2 Delete `Maya.Mailer`, the Swoosh and DNSCluster deps, config and router mailbox route; `mix deps.unlock --unused`; verify `mix compile --warnings-as-errors`

## 2. Tests (test first)

- [x] 2.1 Core components tests (flash, button, input types, header, table and stream rows, list, show and hide, error translation); verify they pass and `MayaWeb.CoreComponents` is above 95%
- [ ] 2.2 `mix maya.import` test; verify it prints its line and the data is queryable (local Docker daemon hung on 2026-11-14, so DB tests run in CI only; see the PR)

## 3. Coverage report and floor

- [x] 3.1 LCOV record test, then `Maya.LcovCoverage`; verify `cover/lcov.info` has one record per source file and the table and threshold still print
- [x] 3.2 Raise the threshold to the measured total rounded down (89: 421 of 472 lines, from the CI table on main plus the new CoreComponents lines); verify a run below it exits non-zero
- [x] 3.3 Codecov upload step in `.github/workflows/ci.yml` that never fails CI

## 4. Docs and gates

- [x] 4.1 Codecov badge at the top of README.md
- [x] 4.2 Run every gate (`factory:test`); verify each exit code
