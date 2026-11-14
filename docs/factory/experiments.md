# Factory experiments

One change at a time, kept only when its metric improves. Opened and closed by `factory:improve` (FACTORY.md "Flywheel"). Metric names are the columns of `~/maya-factory/metrics.csv`; values are medians over 5 retros.

Last improve run: 2026-11-14T18:04:49Z

Status: `running` (next 5 retros pending), `kept` (target met or metric improved), `reverted` (not improved, revert PR merged).

| id | change | metric | baseline | target | status | PRs |
|---|---|---|---|---|---|---|
| E1 | `factory:build` step 9: merge main and finish everything before the first push, then no push until the first CI run finishes | first_pass_green | 60% | 100% | running | #36 |
