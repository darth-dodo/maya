# Proposal: tshirt-sizes

## Why

Factory estimates are hours (30m, 1h, 2h), which read as a promise and cap at 2h, so work bigger than a block (for example #75 realtime transcription) gets a "2h" label it will never meet. Abhishek asked on 2026-11-15: "Factory move to t-shirt sizes". Sizes say how big the work is, keep the cut rule, and give a clear "too big, split it" signal.

## What Changes

- Every Issue estimate becomes a T-shirt size. Default scale (Abhishek may correct it in the spec PR):

  | Size | Means | Rough time | Midpoint hours (retro `estimate_h`) |
  |---|---|---|---|
  | XS | a line or doc tweak | under 30m | 0.25 |
  | S | one focused change | 30m to 1h | 0.75 |
  | M | a feature slice | 1 to 2h | 1.5 |
  | L | a block | 2 to 4h | 3 |
  | XL | too big | over 4h | must be split before build; never built as XL |

- The cut rule becomes: past 2x the size's upper bound, propose the cut (XS past 1h, S past 2h, M past 4h, L past 8h). The F1 3h kill switch is history and stays as written.
- `factory:plan` refuses to file an XL Issue and proposes a split into Issues of L or smaller.
- `factory:retro` records a `size` column and keeps `estimate_h` as the size midpoint, so old rows still compare.
- `factory:improve`, `factory:recap` and `next-task` use sizes.
- GitHub Project 1 Estimate field gains XS, S, M, L, XL; every open Issue is re-sized by judgement (list in design.md); the old 30m, 1h, 2h options are removed only after every item moved.
- Docs updated in the build: CLAUDE.md, FACTORY.md, the skills, docs/factory/LESSONS.md if a rule changes.

Out of scope: story points, velocity charts, rewriting old retro rows' `estimate_h`. New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities

- `factory-process`: how the Maya factory sizes, files, cuts and measures work (Issue estimates, the cut rule, retro size records, the board Estimate field).

### Modified Capabilities

None.

## Impact

- Skills: `project-manager`, `factory-plan`, `factory-retro`, `factory-improve`, `factory-recap`, `next-task`.
- Docs: CLAUDE.md, FACTORY.md, docs/factory/LESSONS.md (if a rule changes).
- GitHub Project 1 Estimate field, and every open Issue's Estimate value and "## Estimate" body section.
- `~/maya-factory/metrics.csv` gains a `size` column (outside the repo).
- No app code, no runtime, no voice loop change.
- Issue: filed by `factory:plan` and linked from the spec PR.
