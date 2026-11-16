# Tasks: team-collapse

One build PR, 1h, after #89 merges (it touches the same band markup).

## 1. Collapsible Team

- [ ] 1.1 Wrap `#team` in `<details id="team-details">` with `<summary id="team-summary">` (lead chip, "+ K more", chevron `aria-hidden`), `phx-mounted={JS.ignore_attributes(["open"])}`. Verify: LiveView tests for "Collapsed by default", "Team of one" and "New member never opens the list" (no `open` attribute, summary text, 6 `.mon` in `#team`), and the existing Talk screen tests pass unchanged.
- [ ] 1.2 CSS in the Talk block: summary at least 44px, chevron turn on `--maya-duration`, no default marker, only `--maya-*` tokens, no height animation. Verify: `mix test test/maya_web/colour_gate_test.exs test/maya_web/design_tokens_test.exs`.

## 2. Browser evidence

- [ ] 2.1 Playwright at 375x667 in both themes: collapsed band height equal for 1 and 6 members and shorter than open; summary text; open after a tap and closed after a second; still open after a `talk_state` update and a Team update; band and button heights the same across moments, open and closed; reduced motion. Verify: computed values in the PR.
- [ ] 2.2 Before and after screenshots of the band, both themes, 6 member Team, collapsed and open; `Phone check:` line from a real phone. Verify: in the PR body.

## 3. Docs

- [ ] 3.1 Changelog fragment, `git diff --quiet origin/main -- assets/js/talk_hook.js`. Verify: `openspec validate --all --strict`, `mix precommit` and `mix credo` green.

## Workflow follow-up

- Archive with `openspec-archive-change team-collapse` in the build PR.
