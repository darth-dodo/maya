# 003: OpenSpec owns the spec station

- Status: Accepted
- Date: 2026-11-14

## Why

- Matt `to-spec` publishes specs to GitHub Issues, so behaviour rules (spoilers 0, 2 to 3 sentence answers, 5 second latency) live outside the repo and drift.
- Builders work in their own worktrees and sessions. They need the rules next to the code, readable at any commit.
- Three skill sets (Matt, Superpowers, OpenSpec) overlap. FACTORY.md rule 1 needs one owner per station.

## What

OpenSpec 2.0 (`brew install openspec`, https://github.com/Fission-AI/OpenSpec) owns specs. Nothing else changes owner.

| Station | Owner |
|---|---|
| Interview, PRODUCT.md | Matt `grill-with-docs` |
| Specs and proposals | OpenSpec `openspec-propose`, `openspec-update-change`, `openspec-sync-specs`, `openspec-archive-change`, `openspec-explore` |
| Work queue | GitHub Issues, one per OpenSpec change |
| Build and verify | Superpowers |
| Review | Matt `code-review` |

## How

- `openspec init --tools claude` wrote `openspec/` and six skills in `.agents/skills/`, linked from `.claude/skills/`. Never edit those skill files: `openspec update` regenerates them.
- `openspec/config.yaml` carries Maya's non-obvious constraints (spoilers, answer length, latency budget, build with Superpowers) and artifact rules (out of scope, testable scenarios, latency scenarios, 2 hour tasks).
- Plan: `openspec-propose <change>` writes `openspec/changes/<id>/` (proposal, design, specs, tasks). `project-manager` opens one Issue per change that links it.
- Build: the builder follows the change's `tasks.md` and `specs/` with Superpowers TDD, then runs `openspec-archive-change` in the same PR. Specs and code merge together.
- Enforced in `.claude/settings.json` deny rules: `openspec-apply-change` (competes with Superpowers build), Matt `to-spec` and `to-tickets` (replaced).

## Consequences

- Easier: behaviour rules versioned with the code; Matt `code-review`'s Spec axis and every builder read the same files.
- Harder: one more CLI and skill set; each PR must remember to archive its change (PR template checkbox).
- Revisit when: archiving is skipped often, or OpenSpec's generated skills start fighting Superpowers despite the deny rules.
