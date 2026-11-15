# design-system Specification

## Purpose
Gives Maya one visual foundation, Calm Emerald by day and Emerald night after dark: colour, type, shape, depth and motion tokens, self-hosted fonts, daisyUI on the tokens, a gate against colour literals and written rules in `docs/design-system.md`.

## Requirements

### Requirement: Colour tokens for day and night

The stylesheet SHALL define each Maya colour token with a day value and a night value. Night values SHALL apply when `data-theme="dark"` is set, and when `data-theme="light"` is not set and the system prefers dark. `--maya-hairline` SHALL be transparent by day and gold at night.

#### Scenario: Every token has both values

- **WHEN** the built stylesheet is read
- **THEN** `--maya-bg`, `--maya-sea`, `--maya-surface`, `--maya-ink`, `--maya-muted`, `--maya-action`, `--maya-action-ink`, `--maya-line`, `--maya-hairline`, `--maya-accent`, `--maya-listen`, `--maya-wait`, `--maya-success` and `--maya-error` are each defined in the day scope and again in both night scopes (`[data-theme="dark"]` and the `prefers-color-scheme: dark` media block)

#### Scenario: Hairline only at night

- **WHEN** the page renders with `data-theme="light"`
- **THEN** `--maya-hairline` computes to transparent, and with `data-theme="dark"` it computes to `#b58a2a`

### Requirement: Contrast of token pairs

Every text pair of tokens SHALL reach at least 4.5:1 and every non-text pair used as the only cue for a state or control SHALL reach at least 3:1, in both themes. The pairs and their ratios SHALL be listed in `docs/design-system.md`.

#### Scenario: Contrast pairs checked

- **WHEN** a test computes the WCAG contrast ratio of each listed pair from the token values in `app.css`
- **THEN** ink, muted, accent, success and error on their backgrounds and action-ink on action are each at least 4.5:1, and listen and wait on the scene are each at least 3:1, for day and for night

### Requirement: daisyUI follows the tokens

Both daisyUI themes (`light` default, `dark` for a dark preference) SHALL take their colours from the Maya tokens, so daisyUI `primary` is the emerald action colour and no default component uses the Phoenix purple.

#### Scenario: Primary is emerald

- **WHEN** the stylesheet is built
- **THEN** each daisyUI theme sets `--color-primary` to the `--maya-action` value for its theme, and no `oklch(... 277...)` or other Phoenix default theme colour remains

### Requirement: No colour literals outside the token layer

Colour literals (`#` hex, `rgb()`, `rgba()`, `hsl()`, `oklch()`) SHALL appear only inside the token layer of `assets/css/app.css`, marked by `/* tokens:start */` and `/* tokens:end */`. Component CSS, `.ex` and `.heex` files under `lib/maya_web` SHALL use tokens. The only exceptions are the `theme-color` metas in the root layout. A test in CI SHALL enforce this.

#### Scenario: Literal outside the layer fails CI

- **WHEN** a rule outside the token layer uses `color: #123456`
- **THEN** the colour gate test fails and names the file and line

#### Scenario: Clean tree passes

- **WHEN** the gate test runs on a tree that uses only tokens outside the layer
- **THEN** it passes, and any temporary allow list it reports is empty once `design-apply` ships

### Requirement: Self-hosted fonts

Maya SHALL use Fraunces for headings and Inter for body text, buttons and labels, both served as woff2 from Maya's own host under `/fonts/`, with `font-display: swap` and system fallbacks. Both licences SHALL be SIL Open Font License 1.1, committed next to the font files and recorded in `docs/design-system.md`. The Content Security Policy SHALL be unchanged.

#### Scenario: Font served from self

- **WHEN** a client requests a font file under `/fonts/`
- **THEN** the response is 200 with content type `font/woff2`

#### Scenario: Digested font is cached long

- **WHEN** a production build serves the digested font path with `?vsn=d`
- **THEN** the response has `cache-control` containing `max-age=31536000`

#### Scenario: No third party font host

- **WHEN** any page is rendered
- **THEN** no stylesheet or font URL points to a host other than Maya's own, and the CSP header still has `font-src 'self'`

#### Scenario: Licences committed

- **WHEN** the repo is checked out
- **THEN** `priv/static/fonts/` holds an OFL text for Fraunces and for Inter

### Requirement: Shared type, shape, depth and motion scales

The stylesheet SHALL define one type scale (`--maya-text-xs` to `--maya-text-3xl`), one radius scale (`--maya-radius-sm`, `-md`, `-lg`, `-pill`), one shadow scale (`--maya-shadow-1`, `--maya-shadow-2`), and one motion duration and easing (`--maya-duration`, `--maya-ease`). No shadow SHALL have zero blur.

#### Scenario: Scales defined

- **WHEN** the built stylesheet is read
- **THEN** every scale token above is defined, and no `box-shadow` value in it has a zero blur radius

### Requirement: Reduced motion turns movement off

Under `prefers-reduced-motion: reduce`, `--maya-duration` SHALL be `0ms` and no element SHALL animate.

#### Scenario: Reduced motion

- **WHEN** a page renders with reduced motion emulated
- **THEN** the computed `animation-name` of the Talk ring, the sound wave and the Poké facts is `none`, and `--maya-duration` computes to `0ms`

### Requirement: Written design system

`docs/design-system.md` SHALL describe the principles (Calm Emerald by day, Emerald night, no retro accents), every token with its day and night value, the scales, the contrast pairs, fonts with version, licence and source, and a do and don't list. It SHALL link the claude.ai Design System artifact, or say that the artifact step is pending for the main session.

#### Scenario: Doc lists every token

- **WHEN** a test reads `docs/design-system.md` and the token layer of `app.css`
- **THEN** every `--maya-*` token defined in the layer is named in the doc
