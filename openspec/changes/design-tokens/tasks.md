## 1. Tokens and daisyUI

- [ ] 1.1 Failing tests first (Superpowers TDD): token names in day and both night scopes, contrast pairs from `app.css` values, daisyUI primary equals `--maya-action`, no Phoenix purple left; verify they fail with `mix test`
- [ ] 1.2 Add the token layer (`/* tokens:start */` to `/* tokens:end */`) with the colour, type, radius, shadow and motion tokens from design.md, day on `:root`, night on `[data-theme="dark"]` and the `prefers-color-scheme: dark` block; verify 1.1 token and contrast tests pass
- [ ] 1.3 Rewrite both daisyUI theme blocks onto the tokens (`var()` first, literals inside the layer as the fallback); verify the daisyUI test passes and one daisyUI button renders emerald in both themes (screenshot)

## 2. Colour gate

- [ ] 2.1 Gate test over `assets/css/app.css` and `lib/maya_web/**/*.{ex,heex}`: fails on colour literals outside the token layer, allows only the root layout `theme-color` metas, and holds a named, counted allow list for today's per-page blocks (`.talk-screen`, home, factory, footer SVG in `layouts.ex`); verify it fails on a planted `#123456` and passes after removing it

## 3. Fonts

- [ ] 3.1 Fetch Fraunces and Inter variable Latin woff2 with `npm pack` into the scratchpad (not `package.json`), copy to `priv/static/fonts/`, commit both OFL texts; verify both licence files say SIL Open Font License 1.1 and the font sizes are noted
- [ ] 3.2 `@font-face` in the token layer, `--maya-font-head` and `--maya-font-body`, body and headings use them, at most one Inter preload in `root.html.heex`; verify a test gets 200 `font/woff2` for each file and the CSP test still passes unchanged
- [ ] 3.3 Prod cache check: `MIX_ENV=prod mix assets.deploy`, run prod locally, `curl -I` the digested font path with `?vsn=d`; verify `max-age=31536000` and paste the output in the PR

## 4. Motion

- [ ] 4.1 Extend the existing reduced motion block: `--maya-duration: 0ms`, no animations; transitions use `--maya-duration` and `--maya-ease`; verify with Playwright reduced motion emulation that the ring, wave and Poké facts have `animation-name: none` (screenshot or evaluate output in the PR)

## 5. Docs and reference

- [ ] 5.1 Write `docs/design-system.md` in the shape of habla-hermano's: principles, tokens table day and night, scales, contrast pairs, fonts (version, licence, source), do and don't; verify the doc test (every `--maya-*` token is named) passes
- [ ] 5.2 Create the claude.ai Design System artifact from the Artifact tool's Design System type with the same tokens and link it from the doc; if the builder cannot, write the step in the PR body for the main session; verify the link or the recorded step
- [ ] 5.3 Before and after screenshots of `/`, `/talk`, `/factory` in light and dark at 375 px: only colour and type differ; verify by eye and attach

## 6. Close out

- [ ] 6.1 Changelog fragment; `mix precommit` and `mix credo` green; `openspec validate design-tokens --strict` valid; archive this change with `openspec-archive-change` in the same PR; CI green
