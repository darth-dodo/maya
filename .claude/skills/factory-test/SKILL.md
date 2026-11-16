---
name: factory:test
description: Use before opening or updating a Maya PR, or when asked whether a branch passes, to run every local gate CI and the definition of done expect and report each one with its real exit code.
---

# factory:test

Mirrors the CI jobs behind `ci-success` (format, credo, test with coverage, security, docker) plus the checks CI cannot run. Report a table: gate, command, exit code, one line of evidence. Never pipe a gate through `tail` or `grep` when judging it: that hides the exit code. Run each gate on its own.

## Always

| Gate | Command |
|---|---|
| DB up | `docker compose -p maya up -d --wait db` (the `-p maya` reuses the main checkout's container from a worktree) |
| Compile | `MIX_ENV=test mix compile --warnings-as-errors` |
| Format | `mix format --check-formatted` |
| JS tests (in CI's format job) | `node --test test/js/*_test.mjs` |
| Credo | `mix credo` |
| Tests + coverage floor | `MIX_ENV=test mix test --cover` (fails below the `test_coverage` threshold in `mix.exs`) |
| Dependency audit | `mix deps.audit` |
| Security scan | `mix sobelow --exit high` |
| Spec coverage | Every scenario in the change's `specs/` has a test that asserts it; list scenario -> test file:line |
| Changed changes | `openspec validate <change-id> --strict` for each change the branch touches |

## When the branch touches deploy files

`render.yaml`, `Dockerfile`, `rel/`, `config/runtime.exs`, `lib/maya/release.ex`: run the `render-deploy` skill's "Before opening a deploy PR" smoke test (docker build, run, `curl /health`).

## When the branch touches the voice loop

Per-stage latency, before and after: mic release, STT, agent, TTS first byte, playback start. No harness yet: until one exists, state that the numbers are missing and why. Never invent them.

## Result

All gates green: say so plainly. Any red: stop, use `superpowers:systematic-debugging`, fix the cause, rerun every gate.
