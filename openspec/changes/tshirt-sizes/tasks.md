## 1. Skills and docs

- [ ] 1.1 `project-manager`: template "## Estimate" is `XS | S | M | L | XL` with the size table; progress check cuts past 2x the size's upper bound; verify with `grep -n -E '30m|1h \||2h' .claude/skills/project-manager/SKILL.md` returning no estimate lines
- [ ] 1.2 `factory-plan`: step 6 sizes the Issue and refuses XL, proposing a split into L or smaller; verify by reading the step table
- [ ] 1.3 `factory-retro`: `size` appended as the last header column, `estimate_h` is the size midpoint (XS 0.25, S 0.75, M 1.5, L 3); verify the header line and column rules
- [ ] 1.4 `factory-improve`, `factory-recap`, `next-task`: show sizes; blank `size` in old rows reads as unknown; `next-task` lists the size per Issue and never starts an XL; verify by running `next-task` and `factory:recap` once
- [ ] 1.5 CLAUDE.md and FACTORY.md: cut rule reads "past 2x the size's upper bound", FACTORY.md examples use sizes; verify `grep -rn -iE '2x estimate|estimate 1h' CLAUDE.md FACTORY.md` is empty
- [ ] 1.6 docs/factory/LESSONS.md: update any rule that names hour estimates; verify with grep
- [ ] 1.7 Append `size` to the header of `~/maya-factory/metrics.csv` with blank values for old rows; verify `head -1` and that `factory:recap` still runs

## 2. Board migration

- [ ] 2.1 Add XS, S, M, L, XL to the Estimate field next to the old options; verify with `gh project field-list 1 --owner darth-dodo --format json`
- [ ] 2.2 Set every open Issue to its size from design.md on the board and in its "## Estimate" body section; verify with `gh project item-list`
- [ ] 2.3 Set every closed item by the old mapping (30m to S, 1h to M, 2h to L); verify no item uses an old option
- [ ] 2.4 Remove 30m, 1h, 2h; verify the field lists only XS, S, M, L, XL and no item lost its value

## 3. Close out

- [ ] 3.1 Changelog fragment added; `openspec validate tshirt-sizes --strict` is valid; CI green

## Workflow follow-up

- Archive this change with `openspec-archive-change` in the build PR.
- If `factory-ask` merged first, update its routing to use sizes in the same build PR.
