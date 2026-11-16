# Factory experiments

One change at a time, kept only when its metric improves. Opened and closed by `factory:improve` (FACTORY.md "Flywheel"). Metric names are the columns of `~/maya-factory/metrics.csv`; values are medians over 5 retros (`escaped_defects` is a sum, since its median is almost always 0).

The public `/factory` page shows this table and the backfill below; `test/maya_web/controllers/factory_page_test.exs` fails until the page matches a new or changed row.

Last improve run: 2026-11-16T20:05:39Z

Status: `running` (next 5 retros pending), `kept` (target met or metric improved), `reverted` (not improved, revert PR merged), `inconclusive` (the metric could not see what the change guards; the change stays only with a stated reason).

| id | change | metric | baseline | target | status | PRs |
|---|---|---|---|---|---|---|
| E1 | `factory:build` step 9: merge main and finish everything before the first push, then no push until the first CI run finishes | first_pass_green | 60% | 100% | kept (80% over #42, #44, #46, #47, #48; 100% without #42's Hex outage) | #36 |
| E2 | CI setup falls back to the `cdn.jsdelivr.net/hex` mirror when `builds.hex.pm` fails | first_pass_green | 80% | 100% | kept (100%, 5 of 5 over #53, #54, #55, #59, #60; no Hex download failure) | #52 |
| E3 | The hourly post-deploy smoke check asks production one real Question (`POST /health/ask`, gated by `SMOKE_TOKEN`) and opens a `bug` Issue on a non-200, an empty Answer or the agent error line | escaped_defects | 1 per 5 PRs | 0 | inconclusive (1 over #65, #69, #71, #73, #74: a phone-only bug a text Question cannot catch; probe kept) | #63 |
| E4 | `factory:review` blocks a PR that touches `assets/js/talk_hook.js`, `lib/maya_web/live/talk_live.ex` or `assets/css/app.css` until its body has a `Phone check:` line from a real phone, run on the branch before merge | escaped_defects | 7 per 27 PRs (4 from the phone) | 0 from the phone | running | #129 |

## Review reward backfill

Snapshot of `~/maya-factory/metrics.csv` read on 2026-11-15 (23 rows, PRs #16 to #60), so the public `/factory` page cites only numbers in the repo. A tested fix is a finding whose `file:line` a later commit changed with a test that fails without the change (FACTORY.md "Flywheel"); per PR it is `review_findings` times `review_precision`.

- Findings: 67 in all, on the 10 PRs with scored findings.
- Tested fixes: 4 of 67 findings led to a tested fix (#22, #24, #55).
- Precision: `review_precision` median 0.00 over those 10 PRs, highest 0.20 (#22).
- Escaped defects: 3 (#22, #48, #55). 2 of 3 escaped defects were missed: no finding flagged them (`review_misses`, #22 and #55).

## Candidates

Process ideas waiting for an experiment, added by `factory:ask` (Experiment route). `factory:improve` step 3 prefers a candidate whose metric is the worst metric and removes its row when it opens the experiment.

| date | change | metric | hypothesis | words |
|---|---|---|---|---|
| 2026-11-15 | Require branches to be up to date before merging on `main` (`gh api -X PATCH repos/darth-dodo/maya/branches/main/protection/required_status_checks -F strict=true`), so CI runs on the merge result | first_pass_green | #63 and #65 each passed CI alone and broke main together (#72), which turned #73 and #74 red on their first run | none, added by factory:improve run 4 (#125) |
