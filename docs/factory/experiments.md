# Factory experiments

One change at a time, kept only when its metric improves. Opened and closed by `factory:improve` (FACTORY.md "Flywheel"). Metric names are the columns of `~/maya-factory/metrics.csv`; values are medians over 5 retros (`escaped_defects` is a sum, since its median is almost always 0).

Last improve run: 2026-11-14T23:38:27Z

Status: `running` (next 5 retros pending), `kept` (target met or metric improved), `reverted` (not improved, revert PR merged).

| id | change | metric | baseline | target | status | PRs |
|---|---|---|---|---|---|---|
| E1 | `factory:build` step 9: merge main and finish everything before the first push, then no push until the first CI run finishes | first_pass_green | 60% | 100% | kept (80% over #42, #44, #46, #47, #48; 100% without #42's Hex outage) | #36 |
| E2 | CI setup falls back to the `cdn.jsdelivr.net/hex` mirror when `builds.hex.pm` fails | first_pass_green | 80% | 100% | kept (100%, 5 of 5 over #53, #54, #55, #59, #60; no Hex download failure) | #52 |
| E3 | The hourly post-deploy smoke check asks production one real Question (`POST /health/ask`, gated by `SMOKE_TOKEN`) and opens a `bug` Issue on a non-200, an empty Answer or the agent error line | escaped_defects | 1 per 5 PRs | 0 | running | #63 |
