# Proposal: error-monitoring

## Why

Production errors reach Abhishek only when he hits them on the phone: #55 took a phone test and a pasted Render trace. Factory idea from Abhishek on 2026-11-15 (#87); Sentry approved on 2026-11-21, free Developer plan only. Decision and privacy rules: ADR-010.

## What Changes

- **Sentry, server side only**: the official `sentry` Hex package, configured in `config/runtime.exs` from `SENTRY_DSN`. Unset means off (dev, test, CI).
- **Captures**: crashes in the Conversation, the Agent and turn Tasks, LiveView and controller errors, and logger errors at error level. `Logger.warning` lines (#60) become breadcrumbs, not events.
- **Release and environment**: `release` is `RENDER_GIT_COMMIT`, `environment` is set.
- **Scrubbing**: a `before_send` strips request bodies, LiveView event params, cookies, headers and long strings; tags only stage (`stt`, `agent`, `tts`, `import`) and reason atoms.
- **Config**: `SENTRY_DSN` in render.yaml (`sync: false`), `.env.template` (name only), the FACTORY.md secrets table and the `render-deploy` skill.
- **Docs**: ADR-010 Accepted; the frozen stack in CLAUDE.md and the `settled-architecture` skill list Sentry.

Size: M (one build PR).

Out of scope: browser side Sentry, performance tracing and session replay (all send more data than needed), and any paid plan.

## Capabilities

### New Capabilities

- `error-monitoring`: errors reach Sentry with commit and stage, scrubbed to metadata.

### Modified Capabilities

None.

## Impact

- Code: `mix.exs` (`sentry`), `config/runtime.exs`, `lib/maya/application.ex` (logger handler), a scrubber module, tests.
- Config: render.yaml, `.env.template`, FACTORY.md, `render-deploy` skill, CLAUDE.md, `settled-architecture`.
- Voice loop: none; sending is async in Sentry's own process.
- CSP: unchanged (no browser SDK).
- Issue: #87.
