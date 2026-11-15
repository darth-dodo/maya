# Tasks

## 1. Numbers in the repo

- [ ] 1.1 Add a dated "Review reward backfill" section to `docs/factory/experiments.md` from `~/maya-factory/metrics.csv` (findings, tested fixes, median precision, escaped defects and misses); verify each number against the CSV with a one-line `awk` shown in the PR

## 2. The page

- [ ] 2.1 Route `get "/factory"` in the public pipeline with heading, title, footer and no noindex; verify "Visitor opens the factory page" and "Indexable" pass
- [ ] 2.2 Stations and gates sections with the `ci.yml` wording test; verify "Four stations in order", "Three gates" and "Spoiler gate wording stays honest" pass
- [ ] 2.3 Flywheel with `#experiments` and `#review-reward`, plus the test that parses `docs/factory/experiments.md`; verify "Rows match the experiments log", "Backfill shown" and "Flywheel parts" pass
- [ ] 2.4 Source links and copy checks; verify "Links present" and "Inclusive and spoiler-free copy" pass

## 3. Docs and checks

- [ ] 3.1 FACTORY.md: one line pointing at `/factory`; verify with `grep -n '/factory' FACTORY.md`
- [ ] 3.2 After deploy, `curl -s -o /dev/null -w '%{http_code}' <live>/factory` prints 200 without credentials; output in the PR

## Workflow follow-up

- Archive the change with `openspec-archive-change` in the same PR.
- Changelog fragment `changelog.d/<branch-with-dashes>.md`.
