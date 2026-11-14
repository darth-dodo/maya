# Tasks

## 1. Version endpoint (TDD with Superpowers)

- [ ] 1.1 Write tests for every `service-health` scenario (liveness with no session cookie, version known via `RENDER_GIT_COMMIT`, version `unknown`); verify they fail for the version cases
- [ ] 1.2 Add `GET /health/version` next to `/health` (no pipeline) returning `RENDER_GIT_COMMIT` or `unknown`; verify the tests pass and `/health` still returns exactly `ok`

## 2. CI jobs and aggregate check

- [ ] 2.1 Split `.github/workflows/ci.yml` into parallel `format`, `credo`, `test` (with the pgvector service), `docker` and `security` jobs, plus `ci-success` (`needs:` all, `if: always()`, fails unless all succeeded); verify on the PR that each job appears and `ci-success` is green
- [ ] 2.2 Docker job: build the image with layer caching, run it with a generated `SECRET_KEY_BASE` and unreachable `DATABASE_URL`, poll `/health` up to 60 s; verify by pushing a temporary commit that breaks `config/runtime.exs` and seeing the docker job fail, then revert it
- [ ] 2.3 Add `mix_audit` and `sobelow` (only: [:dev, :test], runtime: false); security job runs `mix deps.audit` and `mix sobelow` failing on high confidence; verify both run clean on the PR and record any suppression with its reason

## 3. Post-deploy smoke check

- [ ] 3.1 Add `.github/workflows/post-deploy.yml` on push to main: poll `/health/version` for `$GITHUB_SHA` (30 s interval, 20 min limit), then curl `/` and `/health`, open an Issue labelled `bug` on failure; concurrency group cancels older runs; verify with `actionlint` or a dry run that the script parses

## 4. Docs and settings

- [ ] 4.1 Update FACTORY.md, ADR-001 guardrails, `factory:test` and the `render-deploy` skill to name `ci-success` and the new jobs; verify `git grep -n "\`test\` check"` finds no stale reference
- [ ] 4.2 Run `factory:test`; verify all gates green

## Workflow follow-up

- Run `openspec-archive-change` for `ci-cd-hardening` in the same PR before merge.
- After the PR shows `ci-success` green, Abhishek switches branch protection's required check from `test` to `ci-success`, then merges.
- After merge, verify the first post-deploy run passes (Actions tab) and comment the run link on the Issue.
