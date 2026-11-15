## Why

Maya is public on Render. Anyone with the URL can open the Talk screen and spend OpenRouter and Mistral credit. Friends share one login (Issue #49). The homepage change (#90, built in #91) needs this login in place so it only has to move the Talk route.

## What Changes

- One shared login (HTTP Basic auth) in front of the Talk screen (today `/`) and `POST /fresh`, built as a reusable router pipeline so #91 moves the route without touching the login.
- Without the login, or with the wrong one, those routes answer 401 with a `www-authenticate` header.
- `/health`, `/health/version`, `/health/ask` (its own `SMOKE_TOKEN`), static files, `/manifest.webmanifest` and `/robots.txt` stay public.
- Credentials come from `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD`. Production refuses to boot without them, so a deploy that misses them fails and Render keeps the last good version.
- Docs: render.yaml, `.env.template`, FACTORY.md secrets table, render-deploy skill, CI docker job env.

Out of scope: moving Talk to `/talk` (#91), per-friend accounts, logout, rate limiting, flipping search indexing back on (the homepage change owns robots per page, its design decision 3). New ideas go to PHASE_2.md.

GitHub Issue: #49.

## Capabilities

### New Capabilities

### Modified Capabilities
- `web-security`: adds the shared login on pages that spend API credit, and the list of routes that stay public.
- `delivery-pipeline`: the post-deploy smoke check expects the Talk screen at `/` to answer 401 (proof the login is on) instead of 200. #91 changes it to `/` 200 and `/talk` 401.

## Impact

`lib/maya_web/router.ex`, `config/runtime.exs`, `config/test.exs`, `test/support/conn_case.ex`, render.yaml, `.github/workflows/ci.yml`, docs. No new dependency: `Plug.BasicAuth` ships with Plug.
