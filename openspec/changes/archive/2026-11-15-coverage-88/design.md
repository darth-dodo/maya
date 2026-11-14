# Design

## Report format without a dependency

Elixir's built-in coverage tool prints the per-module table, enforces `summary: [threshold: N]` and writes HTML, but has no LCOV or other Codecov format ([Mix.Tasks.Test coverage options](https://mix.hexdocs.pm/Mix.Tasks.Test.html)). It accepts a custom `test_coverage: [tool: Module]` whose `start/2` returns a function run after the suite.

`Maya.LcovCoverage` (in `test/support/`, so it is never in the release) wraps the built-in tool: it calls `Mix.Tasks.Test.Coverage.start/2`, and in the returned function it first writes `cover/lcov.info` from `:cover.analyse(mod, :calls, :line)` for every non-ignored module, then runs the built-in report. The table and the threshold behave exactly as before. About 40 lines instead of `excoveralls`, which was the approved fallback.

Codecov reads LCOV ([supported formats](https://docs.codecov.com/docs/supported-report-formats)).

## Upload never fails CI

`codecov/codecov-action@v7` with `token: ${{ secrets.CODECOV_TOKEN }}`, `files: cover/lcov.info`, `disable_search: true`, `fail_ci_if_error: false`, and `continue-on-error: true` on the step, so a missing token, a Codecov outage or an action crash still leaves the test job green (docs/factory/LESSONS.md, Ship). The step runs only after `mix test --cover` passed.

## Floor

Executable lines after the removals: 472 (counted from `cover/lcov.info`). The threshold is the measured total rounded down; the PR shows the measured table.

## Ignored modules

Unchanged plus the coverage tool itself: `Maya.DataCase`, `MayaWeb.ConnCase`, `Maya.Release`, `Maya.LcovCoverage` (test support, like the two cases).
