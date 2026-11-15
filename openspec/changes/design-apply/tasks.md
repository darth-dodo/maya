## 1. Baseline

- [ ] 1.1 Before screenshots of `/`, `/talk`, `/factory` in light and dark at 375 and 1280 px (Playwright, `data-theme` set per shot), saved outside the repo for the PR; verify 12 images exist

## 2. Pages

- [ ] 2.1 Failing Playwright or computed style checks first for the day and night scenarios of the Talk screen, homepage and `/factory` (background, action, hairline, glow, fonts, no purple); verify they fail
- [ ] 2.2 Talk screen block in `app.css` onto tokens: drop its local colour variables, follow the theme, gold hairline and ball glow at night only, Fraunces heading and gym line, Inter Answers and labels, transitions on `--maya-duration` and `--maya-ease`; verify the Talk scenarios pass and every existing `talk_live_test.exs` and `talk_screen_page_test.exs` test passes unchanged
- [ ] 2.3 Homepage and footer SVG in `layouts.ex` onto tokens (`var()` or `currentColor`); verify the homepage scenarios and existing `page_controller_test.exs` pass
- [ ] 2.4 `/factory` onto tokens; verify the factory scenarios and existing `factory_page_test.exs` pass
- [ ] 2.5 Empty the colour gate allow list; verify the gate test passes with zero allowed blocks

## 3. Metadata and brand assets

- [ ] 3.1 `theme-color` metas (`#0f5a3a` light, `#08181a` dark) and manifest colours; verify `site_metadata_test.exs` updated to the modified scenario and passing
- [ ] 3.2 Redraw `maya-icon.svg`, `logo.svg`, `docs/assets/hero.svg`, `docs/assets/footer.svg` on the palette with alt text kept accurate; add the SVG palette test; verify it passes
- [ ] 3.3 Regenerate favicon, app icon and og-image PNGs from the SVG sources at their sizes with a local tool (no new dependency); verify sizes with `file` or `sips -g pixelWidth -g pixelHeight` and paste before and after images

## 4. Evidence and close out

- [ ] 4.1 After screenshots at the same 12 settings, laid out before next to after in the PR; reduced motion check on `/talk` still turns animations off; state that the voice loop is untouched so latency numbers do not change
- [ ] 4.2 Update `docs/design-system.md` if a rule changed while applying; changelog fragment; `mix precommit` and `mix credo` green; `openspec validate design-apply --strict` valid; archive this change with `openspec-archive-change` in the same PR; CI green
