# Tasks

## 1. Login (tests first)

- [x] 1.1 Login tests: `/` and `POST /fresh` 401 without or with wrong credentials, 200 with right ones, LiveView connects; public routes open; ConnCase signs in by default; verify the tests fail first
- [x] 1.2 `:require_login` pipeline in the router on the Talk scope; credentials in config; verify the login tests pass

## 2. Boot guard and config

- [x] 2.1 `config/runtime.exs` reads `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD`, prod raises without them; dev default; test values; verify a prod config load without them fails and with them works

## 3. Docs and deploy

- [x] 3.1 Smoke check expects `/` 401; render.yaml (`sync: false`), `.env.template`, FACTORY.md secrets table, render-deploy skill, CI docker job env; verify by reading the diff

## 4. Gates

- [x] 4.1 Run `factory:test`; verify every gate is green and the coverage floor is not lowered (the test suite ran in CI: local Postgres was down)

## Workflow follow-up

- Archive with `openspec-archive-change basic-auth` in the same PR.
- Abhishek: set the two Render env vars before merging; on the phone, the login is asked once and the home screen app keeps working.
