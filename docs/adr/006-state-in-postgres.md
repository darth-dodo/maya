# 006: Progress and the Conversation live in Postgres

- Status: Accepted
- Date: 2026-11-14

## Context
CLAUDE.md names `progress.json` as the knowledge source for badges, Team and location. Render's disk is replaced on every deploy, so a file written at runtime loses Progress. A Conversation held only in memory is lost on a crash or deploy, and the agent needs the last 5 turns.

## Decision
- `priv/progress.json` is a seed, imported once into a `progress` table. Events (`log_event`) update the table in the same transaction as the Event row; `undo` reverts the last Event.
- There is one Conversation, kept forever. Each Question and Answer (text only, audio discarded) is a `turns` row with per-stage latency in milliseconds.

## Consequences
- Partly superseded by ADR-008: one Conversation per Guest, not one forever.
- Easier: deploys, crashes and reloads keep Progress and history; latency p50 and p95 come from SQL.
- Harder: every turn writes across regions (Frankfurt to Ireland, ADR-002), so writes happen after the Answer starts playing, never on the critical path. The one exception is an Event (#77): its confirm line is the Answer, so `log_event` writes inside the agent stage, only on turns where the Guest reports progress.
- Check: the agent stage timing with and without the turn reads; revisit if history reads show up in Answer time.
