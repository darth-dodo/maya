# Tasks: error-monitoring

One build PR, size M. It says "Closes #87" and archives the change. If it passes 2x, cut the warning breadcrumbs first.

## 1. Dependency and config

- [x] 1.1 Add `{:sentry, "~> 14.0"}`; configure `dsn`, `release` (`RENDER_GIT_COMMIT`), `environment_name` in `config/runtime.exs`; test config uses the Sentry test mode. Verify: app starts with and without `SENTRY_DSN`.
- [x] 1.2 `SENTRY_DSN` in render.yaml (`sync: false`), `.env.template` (name only), FACTORY.md secrets table, `render-deploy` skill. Verify: `grep SENTRY_DSN` hits each.

## 2. Capture and scrub

- [x] 2.1 `Sentry.LoggerHandler` at `:error` with warnings as breadcrumbs; `Sentry.PlugCapture` in the endpoint; stage tag on turn Tasks. Verify: Task crash and breadcrumb tests.
- [x] 2.2 `before_send` scrubber (allow-list). Verify: tests that a turn crash holding a Question, Answer and guest id, and a controller error with cookie and body, send none of them; CSP header test unchanged.

## 3. Docs and live check

- [x] 3.1 ADR-010 Sentry part Accepted; CLAUDE.md frozen stack and `settled-architecture` list Sentry; changelog fragment. Verify: `openspec validate --all --strict`, `mix precommit`, `mix credo` green.
- [ ] 3.2 After deploy: one deliberate test error in Sentry with the commit. Verify: screenshot in the PR (Abhishek sets `SENTRY_DSN`).
