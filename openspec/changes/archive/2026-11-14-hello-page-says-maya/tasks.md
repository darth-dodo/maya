# Tasks

## 1. Landing page (TDD with Superpowers)

- [x] 1.1 Rewrite `test/maya_web/controllers/page_controller_test.exs` to assert every scenario in `specs/landing-page/spec.md` (heading "Maya", tagline, no "Peace of mind from prototype to production", no "Phoenix Framework", no `github.com/phoenixframework` link, title "Maya"); verify `mix test test/maya_web/controllers/page_controller_test.exs` fails for the right reasons
- [x] 1.2 Replace `lib/maya_web/controllers/page_html/home.html.heex` with the heading and tagline inside the existing layout, and drop the " · Phoenix Framework" title suffix in `lib/maya_web/components/layouts/root.html.heex`; verify the test from 1.1 passes
- [x] 1.3 Run `mix precommit` and `mix credo`; verify both are green with no warnings

## 2. Pipeline proof

- [ ] 2.1 Open a PR with `Closes #<issue>`, the PR template filled in and a `CHANGELOG.md` line; verify CI `test` is green
- [ ] 2.2 After Abhishek merges, verify `curl -fsS https://maya-j56u.onrender.com/` contains "Maps, Answers, Yaps, Advice." and the title is "Maya"

## Workflow follow-up

- Run `openspec-archive-change` for `hello-page-says-maya` in the same PR before it is merged, so `openspec/specs/landing-page/spec.md` lands with the code.
- Task 2.2 happens after merge; record the result as a comment on the Issue.
