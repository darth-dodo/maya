# 002: Postgres on Supabase

- Status: Accepted
- Date: 2026-11-14

## Why

- A free Render web service sleeps after 15 minutes and wakes in about a minute, which breaks the 5 second voice answer. So the web service is paid (`0.5c-512mb`, $7/mo).
- Free Render Postgres is deleted 30 days after creation plus 14 days grace. Paid Render Postgres is $6/mo more.
- Supabase free keeps Postgres with pgvector at $0, and has a Frankfurt region next to the Render service.

## What

- Postgres + pgvector on a Supabase free project in Frankfurt (eu-central-1). 500 MB, no backups, paused after 1 week of inactivity.
- Everything else in the frozen stack stays. Only the database host changes.

## How

- Render reads `DATABASE_URL` (Supabase session pooler, port 5432, IPv4) from its env, `sync: false` in `render.yaml`.
- `config/runtime.exs` connects with `ssl:` peer verification against the Supabase Root 2021 CA in `priv/certs/` (public, valid until 2031), `POOL_SIZE` 5.
- Session pooler, not transaction mode, because Ecto uses prepared statements. Not direct, because direct connections are IPv6 only.
- Migrations run in Render's `preDeployCommand` (`/app/bin/migrate`). Enable pgvector with a migration: `CREATE EXTENSION IF NOT EXISTS vector`.
- `/health` does not touch the database, so a paused project never restarts the app.

## Consequences

- Easier: $7/mo total instead of $13, no 30-day expiry.
- Harder: one more account, a manual `DATABASE_URL` secret, a weekly pause to restore by hand, no backups. Game data is re-importable; the journal is not.
- Revisit when: the journal holds data worth keeping, or the pause bites during play. Then move to Supabase Pro ($25/mo) or Render Postgres ($6/mo).

Sources: https://render.com/docs/free, https://supabase.com/pricing, https://supabase.com/docs/guides/database/connecting-to-postgres
