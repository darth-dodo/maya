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
| 002 | [Postgres on Supabase](002-postgres-on-supabase.md) | Accepted |
| 003 | [OpenSpec owns the spec station](003-openspec-for-specs.md) | Accepted |
| 004 | [Facts only from tools and data](004-facts-only-from-tools.md) | Accepted |
| 005 | [Voice transport over the LiveView socket](005-voice-transport-over-liveview.md) | Accepted |
| 006 | [Progress and the Conversation live in Postgres](006-state-in-postgres.md) | Accepted |
