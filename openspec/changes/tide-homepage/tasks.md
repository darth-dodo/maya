# Tasks

Start from main after #130 (merged). Build with Superpowers TDD.

## 1. Baseline

- [ ] 1.1 Before screenshots of `/` in light and dark at 375px (Playwright, `data-theme` set per shot), saved outside the repo for the PR; verify 2 images exist

## 2. Sections

- [ ] 2.1 Update `page_controller_test.exs` to the modified and added scenarios (identity, hero, real turn, Meet Maya, Dials, sayings, loop, band, original art), delete the demo slot and clip tests; verify the new tests fail and the removed ones are gone
- [ ] 2.2 Hero and header: backdrop per theme with the fade, eyebrow, headline, body, pill, mic note, "Open Talk" on `/` only; verify the identity and hero tests pass
- [ ] 2.3 `#real-turn` from `@real_turn` (real Question and Answer from Abhishek) and `#meet-maya` with ball, bubble, tagline, `@dials` bars and 3 sayings; verify the real turn, Meet Maya, Dials and sayings tests pass
- [ ] 2.4 `#voice-loop` as ruled numbered lines and `#spoiler-promise` as the sea band; delete `screenshots/0`, `demo_transcript` and `priv/static/images/demo/`; verify the loop, band and original art tests pass and `grep -rn images/demo lib test` is empty
- [ ] 2.5 Computed style checks with Playwright against the running app, in both themes at 375px: backdrop URL, hero height, headline and Answer sizes, band background, ruled lines; verify every check passes and paste the results in the PR

## 3. Close out

- [ ] 3.1 After screenshots at the same 2 settings next to the before ones; reduced motion leaves nothing animated; 44px targets on `#talk-link` and `#header-talk-link`; colour gate, contrast and font tests green; verify with `mix test test/maya_web`
- [ ] 3.2 Phone check on Abhishek's phone (both themes); `PHASE_2.md` line for a demo clip; `docs/design-system.md` updated if a rule changed; changelog fragment; `mix precommit` and `mix credo` green; verify each command exits 0

## Workflow follow-up

- Archive this change with `openspec-archive-change` in the same PR, then `openspec validate --strict` on the specs.
