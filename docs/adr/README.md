# Architecture Decision Records

Write an ADR when a settled choice changes (see `.claude/skills/settled-architecture`), or when a decision would surprise the next agent.

- File name: `NNN-kebab-title.md`, numbered in order (`001-...`).
- Status: Proposed, Accepted, Superseded by NNN, or Deprecated. Never delete an ADR; supersede it.
- Add every ADR to the index below.

## Template

```markdown
# NNN: Title

- Status: Proposed
- Date: YYYY-MM-DD

## Context
What forces the decision. Measurements if any (latency, cost, memory).

## Decision
What we do.

## Consequences
What gets easier, what gets harder, what we will check.
```

## Index

| # | Title | Status |
|---|---|---|
| 001 | [Agent-run software factory](001-agent-run-software-factory.md) | Accepted |
