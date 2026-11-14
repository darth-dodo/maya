---
name: render-deploy
description: Use when changing render.yaml, the Dockerfile, runtime config or env vars for Maya, checking whether a deploy went live, or debugging a failed Render deploy, health check, migration or database connection
---

# Render deploy

Maya runs as one Docker web service on Render (Frankfurt). Postgres lives on Supabase in Ireland, reached through the session pooler (ADR-002).

## Files

| File | Role |
|---|---|
| `render.yaml` | Blueprint: service, plan, region, health check, pre-deploy, env vars |
| `Dockerfile`, `.dockerignore`, `rel/overlays/bin/*`, `lib/maya/release.ex` | Release image from `mix phx.gen.release --docker` |
| `config/runtime.exs` | Prod config read at boot: DB URL and SSL, host, port, secret |
| `priv/certs/supabase-root-2021-ca.crt` | Supabase public root CA for DB SSL, valid until 2031-04-26 |
| `lib/maya_web/controllers/health_controller.ex` | `/health` (Render's health check) and `/health/version` (deployed commit, from `RENDER_GIT_COMMIT`) |
| `.github/workflows/ci.yml` | Jobs format, credo, test (coverage floor), security, docker (boots the release with no DB) behind the required `ci-success` check |
| `.github/workflows/post-deploy.yml`, `scripts/smoke_check.sh` | Every 15 minutes and on dispatch, never on push (a push-triggered check that waits for the deploy deadlocks `checksPass`): compares `/health/version` with the head of main, checks `/` and `/health` when live, opens one `bug` Issue per commit on a problem, always exits 0. Test: `scripts/smoke_check_test.sh` |

## Rules

- Region `frankfurt` and the service name are permanent. Never change them in `render.yaml`.
- Plan changes cost money: ask Abhishek first.
- `autoDeployTrigger: checksPass`: main deploys only after CI is green. Never switch to `commit`.
- Migrations run in `preDeployCommand: /app/bin/migrate`. A failed migration stops the deploy and the old version keeps serving.
- Secrets are `sync: false`. Abhishek sets them in the Render dashboard. Never put a value in `render.yaml`, a commit or chat.
- `SECRET_KEY_BASE` comes from `mix phx.gen.secret`. `generateValue` is too short for Phoenix (needs 64 bytes).
- Keep `/health` cheap and DB free. A paused Supabase project must not restart the app.
- New env var: add it to `render.yaml` (with `sync: false` if secret), `config/runtime.exs`, and the secrets table in `FACTORY.md`.

## Before opening a deploy PR

1. `mix precommit` and `mix credo` green.
2. `docker build -t maya:local .` succeeds.
3. Smoke test the image: `docker run --rm -p 4001:4001 -e PORT=4001 -e DATABASE_URL=ecto://postgres:postgres@host.docker.internal/maya_dev -e SECRET_KEY_BASE=$(mix phx.gen.secret) maya:local`, then `curl -fsS localhost:4001/health` prints `ok`. Local Postgres has no SSL, so DB errors in the log are expected; `/health` must still answer.

## Test `DATABASE_URL` locally (before touching Render)

Put it in `.env`, then let Abhishek run (prints host, port, user and `CONNECTED` or the error, never the password):

```
set -a; source .env; set +a; mix run --no-start -e '{:ok,_}=Application.ensure_all_started(:postgrex); o=Ecto.Repo.Supervisor.parse_url(System.fetch_env!("DATABASE_URL")) ++ [ssl: [cacertfile: "priv/certs/supabase-root-2021-ca.crt"], types: Postgrex.DefaultTypes]; IO.puts("host=#{o[:hostname]} port=#{o[:port]} user=#{o[:username]}"); case Postgrex.Protocol.connect(o) do {:ok,_} -> IO.puts("CONNECTED"); {:error,e} -> IO.puts(Exception.message(e)) end'
```

Then reproduce the pre-deploy exactly: `docker run --rm --env-file .env -e SECRET_KEY_BASE=$(mix phx.gen.secret) maya:local /app/bin/migrate`.

## Verify a deploy

1. The merged PR's `ci-success` check is green (`gh run list --branch main --limit 1`).
2. Run the smoke check now instead of waiting for the schedule: `gh workflow run post-deploy.yml`, then `gh run view --log` of that run prints `ok: <sha> is live and healthy` (or locally, `scripts/smoke_check.sh` with `DRY_RUN=1`). "deploy in progress" means the commit is under 20 minutes old: wait and rerun. The run is always green; the result is in its log or a `bug` Issue.
3. If it is not live, the Render dashboard shows the deploy state for that commit.
4. `curl -fsS https://<service>.onrender.com/health/version` prints the merged commit SHA.
5. The home page loads over HTTPS and the LiveView socket connects (no reconnect loop or CSP errors in the browser console).

## When it breaks

| Symptom | Likely cause |
|---|---|
| Deploy fails with `SECRET_KEY_BASE is N bytes, needs at least 64` | Key empty or truncated. Regenerate with `mix phx.gen.secret` and paste the whole value |
| Health check fails, deploy never goes live | App not listening on `$PORT`, or boot crash: read the deploy log for `environment variable ... is missing` |
| Pre-deploy fails | Wrong `DATABASE_URL`, or Supabase project paused. Test it locally first (below) |
| `Ecto.InvalidURLError ... path should be a database name` | `DATABASE_URL` is the `https://<ref>.supabase.co` API URL. Use the session pooler URI |
| `nxdomain` for `db.<ref>.supabase.co` | Direct host, IPv6 only. Use the pooler host `aws-0-<region>.pooler.supabase.com` |
| Connects, then `prepared statement ... does not exist` errors | Port 6543 (transaction mode). Use 5432 (session mode) |
| `ssl` or `certificate` errors | Supabase rotated its CA: download the new one (Database Settings > SSL Configuration) into `priv/certs/` and update the path in `config/runtime.exs` |
| Page loads, LiveView keeps reconnecting | Host mismatch: `PHX_HOST` unset and `RENDER_EXTERNAL_HOSTNAME` missing |
| A `bug` Issue "deploy of <sha> failed the smoke check" | Read its Failure line: "not live after 20 minutes" means Render did not deploy (CI red on main, a check still running or failed on that commit, or a Render failure); a URL and status means the app is up but broken. The scheduled check never blocks a deploy and opens one Issue per commit |
| CI green on main but Render never deploys | `checksPass` waits for every check on the commit: look for a check still running or failed (`gh api repos/darth-dodo/maya/commits/<sha>/check-runs`). Never add a push-triggered workflow that waits for the deploy |
| CSP errors in the browser console | Something loads from another origin, or the inline theme script changed: update the `sha256` in `router.ex` (the CSP test prints the mismatch) |
| Too many connections | Lower `POOL_SIZE` in `render.yaml` |
| Everything worked, now DB errors | Supabase free paused after a week idle: restore it in the Supabase dashboard |
