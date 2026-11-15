# landing-page Specification

## Purpose

The public home page at `/`: the hero, the demo slot, the voice loop, the spoiler promise and the footer, open to search engines, with nothing from the web framework's generator.

## Requirements

### Requirement: Maya identity on the home page
The home page at `/` SHALL be public and SHALL have exactly one top-level heading, "Maya", with id `home-heading`, followed by the tagline "Maps, Answers, Yaps, Advice." in `#home-tagline` and the line "So I hear you like Mudkip. Good. Correct choice." in `#home-catchphrase`. It SHALL NOT show the Talk screen (`#talk-screen`) or the Talk heading `#talk-heading`.

#### Scenario: Visitor opens the home page
- **WHEN** a visitor requests `/`
- **THEN** the response is HTTP 200
- **AND** the header link to `/` reads "Maya"
- **AND** the page has one `h1`, `#home-heading`, reading "Maya"
- **AND** `#home-tagline` reads "Maps, Answers, Yaps, Advice."
- **AND** `#home-catchphrase` reads "So I hear you like Mudkip. Good. Correct choice."
- **AND** the page has no `#talk-screen`, no `#talk-heading` and no `#talk-button`

#### Scenario: Way in to the Talk screen
- **WHEN** a visitor requests `/`
- **THEN** the page has a link `#talk-link` to `/talk`

### Requirement: No framework marketing on the home page
The home page and the Talk screen, including the app layout around them, SHALL NOT show web framework generator content: marketing copy, framework documentation or repository links, framework logos or version numbers, or framework names in the page title.

#### Scenario: Generator content is gone
- **WHEN** a visitor requests `/` or `/talk`
- **THEN** the page does not contain the text "Peace of mind from prototype to production"
- **AND** the page does not contain "Phoenix Framework"
- **AND** the page does not link to `github.com/phoenixframework`
- **AND** the page does not link to `phoenixframework.org` or `hexdocs.pm`

#### Scenario: Browser tab title
- **WHEN** a visitor requests `/`
- **THEN** the HTML title is "Maya"

### Requirement: Backdrop images
Maya SHALL serve three backdrop images (tide, dusk, night) from its own origin under `/images/backdrops/`. They are original scenery generated with Gemini and contain no Pokémon, people, text or logos.

#### Scenario: Backdrops are served
- **WHEN** a visitor requests `/images/backdrops/tide.jpg`, `/images/backdrops/dusk.jpg` or `/images/backdrops/night.jpg`
- **THEN** the response is 200 with content type `image/jpeg`

### Requirement: Original art only
The home page SHALL NOT load images, video, captions, fonts, stylesheets or scripts from any host other than its own, and SHALL NOT contain `iframe` or `embed` elements. Every `img` on it SHALL be a screenshot of Maya itself served under `/images/demo/` with non-empty `alt` text.

#### Scenario: Only own assets
- **WHEN** a visitor requests `/`
- **THEN** every `src`, `poster` and stylesheet `href` on the page is a relative path
- **AND** the page contains no `iframe` and no `embed` element
- **AND** every `img` has a `src` starting with `/images/demo/` and a non-empty `alt`

### Requirement: Hero
The home page SHALL open with a hero `#home-hero` holding an Emerald edition Poké Ball drawn in CSS without images (`#pokeball` with class `pokeball-emerald`) over the tide backdrop, and the heading, tagline and catchphrase.

#### Scenario: Hero parts
- **WHEN** a visitor requests `/`
- **THEN** `#home-hero` contains `#pokeball.pokeball-emerald`, `#home-heading`, `#home-tagline` and `#home-catchphrase`
- **AND** `#pokeball` contains no `img` element

### Requirement: Demo slot
The home page SHALL have a demo section `#demo`. Until the clip `priv/static/videos/maya-demo.mp4` exists, `#demo` SHALL show 1 to 4 real screenshots of the Talk screen and no `video`. It SHALL NEVER show made-up data or a placeholder posing as a video.

#### Scenario: Screenshots before the clip
- **WHEN** a visitor requests `/` and `priv/static/videos/maya-demo.mp4` does not exist
- **THEN** `#demo` contains between 1 and 4 `img` elements under `/images/demo/`, each with non-empty `alt`
- **AND** `#demo` contains no `video` element

### Requirement: Demo clip
Once the clip exists, `#demo` SHALL show it as `video#demo-video` from Maya's own origin: muted, inline, no autoplay with sound, with controls so a tap unmutes, a poster image, a captions track and a text transcript `#demo-transcript`. The MP4 SHALL be under 5 MB.

#### Scenario: Clip present
- **WHEN** a visitor requests `/` and `priv/static/videos/maya-demo.mp4` exists
- **THEN** `#demo-video` has the attributes `muted`, `playsinline` and `controls`, a relative `poster`, and a source `/videos/maya-demo.mp4` of type `video/mp4`
- **AND** it has a `track` with `kind="captions"` and a relative `.vtt` `src`
- **AND** `#demo-transcript` has non-empty text

#### Scenario: Size budget
- **WHEN** `priv/static/videos/maya-demo.mp4` exists
- **THEN** its size is under 5,000,000 bytes
- **AND** `GET /videos/maya-demo.mp4` answers 200 with content type `video/mp4`

### Requirement: Voice loop section
The home page SHALL have a section `#voice-loop` showing the loop as four ordered steps `.loop-step`: "Hold", "Transcribe", "Agent with tools", "Speak", with a simple diagram that needs no image file. It SHALL show per-stage latency numbers only once they are measured on the phone and recorded in the repo; until then it SHALL show the note `#latency-pending` and no millisecond or second figures.

#### Scenario: Four steps in order
- **WHEN** a visitor requests `/`
- **THEN** `#voice-loop` has an ordered list of 4 `.loop-step` elements reading "Hold", "Transcribe", "Agent with tools" and "Speak" in that order

#### Scenario: No invented latency
- **WHEN** a visitor requests `/` and no phone latency numbers are recorded in the repo
- **THEN** `#latency-pending` exists
- **AND** the text of `#voice-loop` matches no number followed by "ms" or "s"

### Requirement: Spoiler promise section
The home page SHALL have a section `#spoiler-promise` with three items: `#promise-facts` (Facts only from Maya's own game data, ADR-004), `#promise-horizon` (the Spoiler horizon at the Next gym) and `#promise-ci-gate` (the CI spoiler gate). The CI gate item SHALL say the gate is planned until the CI workflow has a spoiler gate job (#40), and SHALL NOT claim it runs before then.

#### Scenario: Three promises
- **WHEN** a visitor requests `/`
- **THEN** `#spoiler-promise` contains `#promise-facts`, `#promise-horizon` and `#promise-ci-gate`, each with non-empty text

#### Scenario: Gate wording stays honest
- **WHEN** a visitor requests `/` and `.github/workflows/ci.yml` has no job whose id contains "spoiler"
- **THEN** `#promise-ci-gate` contains the word "planned"

#### Scenario: Homepage stays spoiler-free
- **WHEN** a visitor requests `/`
- **THEN** the page names none of the Hoenn gym leaders after Roxanne (Brawly, Wattson, Flannery, Norman, Winona, Tate, Liza, Juan)
- **AND** no evolved form of a Hoenn starter (Grovyle, Sceptile, Combusken, Blaziken, Marshtomp, Swampert)

### Requirement: Site footer
The home page SHALL end with a footer `#site-footer` linking to `/factory`, the GitHub repo `https://github.com/darth-dodo/maya` and its README, with the wave and badges footer art drawn inline (no image file) and hidden from screen readers or given a text alternative.

#### Scenario: Footer links
- **WHEN** a visitor requests `/`
- **THEN** `#site-footer` has links to `/factory`, `https://github.com/darth-dodo/maya` and `https://github.com/darth-dodo/maya#readme`
- **AND** `#site-footer` contains an inline `svg` with `aria-hidden="true"` or a `title`

### Requirement: Homepage is indexable
The home page SHALL be open to search engines: it SHALL NOT carry a `noindex` robots meta, and `/robots.txt` SHALL disallow only `/talk` and `/fresh`.

#### Scenario: No noindex on the home page
- **WHEN** a visitor requests `/`
- **THEN** the page has no `meta[name="robots"]` whose content contains "noindex"

#### Scenario: robots.txt per route
- **WHEN** a visitor requests `/robots.txt`
- **THEN** the response is 200 and contains `Disallow: /talk` and `Disallow: /fresh`
- **AND** it has no line `Disallow: /`

### Requirement: No API credit on the home page
The home page SHALL NOT open a LiveView socket, start a Conversation or call any speech or agent service.

#### Scenario: Static page
- **WHEN** a visitor requests `/`
- **THEN** the page has no `[data-phx-main]` element
- **AND** no Conversation is started for the request

### Requirement: Homepage follows the design system

The homepage SHALL take every colour, font, radius, shadow and transition from the Maya design tokens and SHALL follow the active theme, Calm Emerald by day and Emerald night at night. The hero title and section headings SHALL use the heading font; body copy, buttons and labels SHALL use the body font. The footer art SHALL use token colours, not literals.

#### Scenario: Homepage in both themes

- **WHEN** `/` renders with `data-theme="light"` and again with `data-theme="dark"`
- **THEN** the page background computes to the day `--maya-bg` (`#f6f1e7`) and the night `--maya-bg` (`#08181a`) respectively, and the call to action background computes to that theme's `--maya-action`

#### Scenario: Hero heading font

- **WHEN** `/` renders
- **THEN** the hero `h1` computed font family starts with "Fraunces"

#### Scenario: Footer art without literals

- **WHEN** the colour gate test reads `lib/maya_web/components/layouts.ex`
- **THEN** the footer SVG has no colour literal
