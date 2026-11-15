## MODIFIED Requirements

### Requirement: Page metadata
Every browser page SHALL carry the title "Maya", the description "Maps, Answers, Yaps, Advice. A spoiler-free Pokémon Emerald companion.", a `theme-color` for the light colour scheme set to the day `--maya-action` value (`#0f5a3a`) and one for the dark colour scheme set to the night `--maya-bg` value (`#08181a`), and a viewport with `viewport-fit=cover`.

#### Scenario: Head tags on the Talk screen
- **WHEN** a visitor requests `/`
- **THEN** the page has the description meta, two `theme-color` metas with `prefers-color-scheme` light and dark media whose contents are `#0f5a3a` and `#08181a`, and a viewport containing `viewport-fit=cover`

## ADDED Requirements

### Requirement: Brand assets on the palette

Maya's brand assets SHALL use only colours from the design system palette (the `--maya-*` token values, including the `--maya-ball-*` tokens): `priv/static/images/maya-icon.svg`, `priv/static/images/logo.svg`, the favicon and app icon PNGs, `priv/static/images/og-image.png` (1200 x 630), the web app manifest `theme_color` and `background_color`, and the README art `docs/assets/hero.svg` and `docs/assets/footer.svg`. Their text alternatives SHALL still describe them.

#### Scenario: SVG colours from the palette

- **WHEN** a test collects every colour literal in `maya-icon.svg`, `logo.svg`, `docs/assets/hero.svg` and `docs/assets/footer.svg`
- **THEN** each one is a value of a `--maya-*` token in the token layer of `app.css`

#### Scenario: Manifest colours

- **WHEN** a client requests `/manifest.webmanifest`
- **THEN** `theme_color` is `#0f5a3a` and `background_color` is `#f6f1e7`

#### Scenario: Raster assets regenerated

- **WHEN** the PR is reviewed
- **THEN** the favicon, app icon and og-image PNGs are regenerated from the palette SVG sources, keep their sizes (16, 32, 180, 192, 512, maskable 512, and 1200 x 630), and before and after images are in the PR
