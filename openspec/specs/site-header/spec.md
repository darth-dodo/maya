# site-header Specification

## Purpose

The header every Maya page shares: the "Maya" wordmark, one text link and the theme toggle, and how the day or night theme is chosen, stored and applied before first paint.

## Requirements

### Requirement: One shared header
The pages `/`, `/talk` and `/factory` SHALL render one header `#site-header` with the wordmark "Maya" in the heading font linking to `/`, exactly one text link and the theme toggle `#theme-toggle`. The header SHALL have the same computed height and padding on all three pages, in both themes.

#### Scenario: Header parts
- **WHEN** a visitor requests `/`, `/talk` or `/factory`
- **THEN** the page has one `#site-header` holding a link to `/` reading "Maya", one other text link and one `#theme-toggle`
- **AND** the wordmark's computed font family starts with "Fraunces"

#### Scenario: Same header everywhere
- **WHEN** `/`, `/talk` and `/factory` render at 375px wide, with `data-theme="light"` and again with `data-theme="dark"`
- **THEN** `#site-header` has the same computed height, `padding-top`, `padding-left` and `padding-right` on all three pages

### Requirement: Header link per page
The header's text link SHALL be "Talk" to `/talk` on `/` and `/factory`, and "Home" to `/` on `/talk`. It SHALL be at least 44px tall.

#### Scenario: Link on the homepage and factory page
- **WHEN** a visitor requests `/` or `/factory`
- **THEN** `#header-talk-link` reads "Talk" and links to `/talk`, and the header has no `#header-home-link`

#### Scenario: Link on the Talk screen
- **WHEN** a Guest opens `/talk`
- **THEN** `#header-home-link` reads "Home" and links to `/`, and the header has no `#header-talk-link`

#### Scenario: Link target size
- **WHEN** any of the three pages renders at 375px wide
- **THEN** the header text link has a computed height of at least 44px

### Requirement: One-button theme toggle
The theme toggle SHALL be one `button` `#theme-toggle` of at least 44 by 44px with no border and no background of its own. By day it SHALL show a moon and have the accessible name "Switch to night"; at night a sun and the name "Switch to day". Its icons SHALL be hidden from screen readers. There SHALL be no "system" choice.

#### Scenario: Day state
- **WHEN** a page renders with `data-theme="light"`
- **THEN** `#theme-toggle` has the accessible name "Switch to night" and its visible icon is the moon

#### Scenario: Night state
- **WHEN** a page renders with `data-theme="dark"`
- **THEN** `#theme-toggle` has the accessible name "Switch to day" and its visible icon is the sun

#### Scenario: Plain icon button
- **WHEN** a page renders at 375px wide in either theme
- **THEN** `#theme-toggle` is at least 44px wide and 44px tall, has a transparent computed background and a border width of 0
- **AND** the page has no `[data-phx-theme]` element and no control that sets a "system" theme

### Requirement: Theme choice follows the phone, then the tap
With no stored choice the theme SHALL follow `prefers-color-scheme`, including live changes. A tap on the toggle SHALL switch to the other theme and store the choice in the browser, and a stored choice SHALL win over the phone setting on every later page load. The toggle SHALL work on pages without a LiveView socket.

#### Scenario: First visit follows the phone
- **WHEN** a visitor with no stored choice opens `/` with the colour scheme emulated as dark
- **THEN** `html` has `data-theme="dark"`, and with the scheme emulated as light it has `data-theme="light"`

#### Scenario: Tap switches and is remembered
- **WHEN** a visitor on `/` in the day theme taps `#theme-toggle` and then opens `/talk` and `/factory`
- **THEN** `html` has `data-theme="dark"` on all three pages, and the toggle on each reads "Switch to day"

#### Scenario: Stored choice wins over the phone
- **WHEN** a visitor has stored the day theme and opens `/talk` with the colour scheme emulated as dark
- **THEN** `html` has `data-theme="light"`

#### Scenario: Works without a socket
- **WHEN** a visitor taps `#theme-toggle` on `/` or `/factory`, which have no `[data-phx-main]`
- **THEN** `data-theme` on `html` changes

### Requirement: No theme flash and CSP kept
The theme SHALL be applied by the inline script in the document head before the body renders, so a stored night choice never paints a day frame first. The Content-Security-Policy SHALL keep `script-src` without `'unsafe-inline'`, with the hash updated to the new inline script.

#### Scenario: Theme set before first paint
- **WHEN** a visitor with the night theme stored requests `/`
- **THEN** the inline theme script is in `head`, before `body`, and sets `data-theme="dark"` on `html` before any `body` content is parsed

#### Scenario: CSP hash matches
- **WHEN** a visitor opens `/`, `/talk` and `/factory`
- **THEN** the browser reports no Content-Security-Policy violation, and the `script-src` directive has a `sha256-` source and no `'unsafe-inline'`
