# Tasks

## 1. Tests first (TDD with Superpowers)

- [ ] 1.1 Rewrite `test/maya_web/controllers/page_controller_test.exs` to cover every scenario in `specs/landing-page/spec.md`, selecting by id (`#maya-heading`, `#tagline`, `#pokeball`, `#mudkip-hype`, `#badge-case .badge-slot`); spoiler test refutes all 9 leader names and 8 "<Name> Badge" strings; original-art test checks relative `src` and stylesheet `href` and no `img`; verify the new tests fail for the right reasons

## 2. Layout and page

- [ ] 2.1 Replace the generator header in `Layouts.app` (`lib/maya_web/components/layouts.ex`) with a Maya wordmark and the theme toggle; verify the "Generator content is gone" test passes with the page wrapped in `Layouts.app`
- [ ] 2.2 Rewrite `home.html.heex` inside `<Layouts.app flash={@flash}>`: hero with `#maya-heading`, `#tagline`, CSS `#pokeball`, `#mudkip-hype`, `#badge-case` with 8 slots; add the three palette custom properties and ball styles to `assets/css/app.css`; verify all page tests pass
- [ ] 2.3 Check the page at 375 px and desktop width in a browser (screenshot in the PR); verify the ball and badge row render without overflow

## 3. Verify

- [ ] 3.1 Run `factory:test`; verify all gates green

## Workflow follow-up

- Run `openspec-archive-change` for `pokemon-welcome-page` in the same PR so `openspec/specs/landing-page/spec.md` gets the modified and added requirements.
- After merge, curl the live page for `#badge-case` and the Mudkip line and comment on the Issue.
