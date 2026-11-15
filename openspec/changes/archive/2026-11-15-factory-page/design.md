# Design

## Context

The factory's raw metrics live in `~/maya-factory/metrics.csv` on Abhishek's machine, outside the repo (FACTORY.md "Flywheel"). Only `docs/factory/experiments.md` and `docs/factory/LESSONS.md` are in the repo. The page must cite only repo numbers, so the review backfill has to be committed first. See proposal.md for why.

## Goals / Non-Goals

**Goals:** a static page whose numbers cannot silently drift from the repo docs.

**Non-Goals:** reading GitHub or the metrics file at runtime; charts.

## Decisions

1. **Plain controller page**, same pipeline and footer as the homepage. Copy is hand-written HEEx.
2. **Tests guard the numbers.** A test parses the markdown table in `docs/factory/experiments.md` (rows starting `| E`) and asserts each id, baseline, target and status word is in the matching `#experiments` row, and that the row count matches. A new experiment then fails the test until the page is updated. Alternative (render the table from the markdown at compile time) adds a parser to the app for one table.
3. **Review backfill snapshot.** The build adds a "Review reward backfill" section to `docs/factory/experiments.md` from `~/maya-factory/metrics.csv`, dated. Snapshot read on 2026-11-15 (23 rows): 10 PRs had scored findings, 67 findings in all, 4 led to a tested fix; `review_precision` median 0.00, highest 0.20 (#22); 3 escaped defects (#22, #48, #55), 2 of them with no finding that flagged them (#22, #55). The builder re-reads the file and uses its numbers if they changed, stating the date.
4. **Gate wording test** reads `.github/workflows/ci.yml`, same as the homepage's spoiler promise line.

## Risks / Trade-offs

- [Publishing low precision looks bad] → Abhishek asked for the honest backfill; it is the point of the reward function.
- [Snapshot ages] → The section is dated; `factory:improve` updates it when it logs experiments.
