# Tasks

## 1. Tests first

- [x] 1.1 Add tests in `test/maya_web/controllers/page_controller_test.exs`: `#poke-facts` has 10 to 14 non-empty `.poke-fact` items, no starter evolved form in the facts, no `script` inside `main`; the existing no-spoiler test covers the facts; verify they fail

## 2. Facts and rotation

- [x] 2.1 Add `poke_facts/0` to `MayaWeb.PageHTML` with the 12 facts from `design.md` and render them in `home.html.heex` between the hero and the badge case; verify the tests pass
- [x] 2.2 Add the CSS rotation and reduced-motion rule to `assets/css/app.css`; verify with screenshots at 375 px and 1280 px (no horizontal overflow, one fact visible)

## 3. Gates

- [x] 3.1 Run `factory:test`; verify every gate is green and the coverage floor is unchanged
