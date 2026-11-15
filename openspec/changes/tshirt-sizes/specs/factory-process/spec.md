## ADDED Requirements

### Requirement: Issue estimates are T-shirt sizes

Every factory Issue SHALL state its estimate as exactly one size from XS, S, M, L or XL in its "## Estimate" section, with the board Estimate field set to the same size. The sizes mean: XS a line or doc tweak (under 30m), S one focused change (30m to 1h), M a feature slice (1 to 2h), L a block (2 to 4h), XL too big (over 4h).

#### Scenario: Issue template uses a size

- **WHEN** a planner drafts an Issue with the `project-manager` template
- **THEN** the "## Estimate" section offers `XS | S | M | L | XL` and no hour values

#### Scenario: Board field matches the body

- **WHEN** an Issue is created on GitHub Project 1
- **THEN** its Estimate field is the same size as its "## Estimate" section

### Requirement: XL is never built

An XL Issue SHALL NOT be filed or started. `factory:plan` SHALL refuse to file an XL Issue and SHALL propose a split into Issues of size L or smaller, each with its own "done when".

#### Scenario: Plan refuses XL

- **WHEN** `factory:plan` sizes a change as XL
- **THEN** it files no Issue and proposes a split into two or more Issues of L or smaller

#### Scenario: Builder meets an XL Issue

- **WHEN** `next-task` or `factory:build` finds an open Issue sized XL
- **THEN** it does not start the build and asks for a split first

### Requirement: Cut rule follows the size

The factory SHALL propose a cut when elapsed time on an Issue passes 2x the upper bound of its size: XS past 1h, S past 2h, M past 4h, L past 8h.

#### Scenario: L Issue runs long

- **WHEN** an L Issue has 8.5h elapsed since its first branch commit
- **THEN** the `project-manager` progress check proposes the cut with the reason

#### Scenario: M Issue within bound

- **WHEN** an M Issue has 3h elapsed
- **THEN** no cut is proposed

### Requirement: Retro records size with a comparable midpoint

`factory:retro` SHALL record the Issue's size in a `size` column and SHALL set `estimate_h` to the size midpoint (XS 0.25, S 0.75, M 1.5, L 3), so rows written before sizes still compare on `estimate_h`.

#### Scenario: Retro on a sized Issue

- **WHEN** a retro runs for a merged PR whose Issue is sized M
- **THEN** the metrics row has `size` M and `estimate_h` 1.5

#### Scenario: Old rows stay readable

- **WHEN** `factory:improve` or `factory:recap` reads rows written before sizes
- **THEN** it uses their `estimate_h` as before and reads a blank `size` as unknown, without failing

### Requirement: Factory reports show sizes

`next-task`, `factory:recap` and `factory:improve` SHALL show each Issue's estimate as its size, not hours.

#### Scenario: next-task ranking

- **WHEN** `next-task` prints its ranked list
- **THEN** each Issue line shows its size (for example "#82 S")

#### Scenario: Recap and improve

- **WHEN** `factory:recap` or `factory:improve` mentions an estimate
- **THEN** it names the size, with hours only as the midpoint for comparison

### Requirement: Board migration keeps every item sized

GitHub Project 1's Estimate field SHALL gain the options XS, S, M, L and XL; every open Issue SHALL be re-sized by judgement with its body updated; the options 30m, 1h and 2h SHALL be removed only after no item on the board, open or closed, still uses them.

#### Scenario: Old options still in use

- **WHEN** any item still has Estimate 30m, 1h or 2h
- **THEN** the old options are not removed

#### Scenario: Migration done

- **WHEN** every item has a size on the board and every open Issue has it in its body
- **THEN** the old options are removed and the field lists only XS, S, M, L, XL
