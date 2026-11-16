# landing-page Specification

## Purpose

The public home page at `/`: the hero, a real turn, Meet Maya, the voice loop, the spoiler promise band and the footer, open to search engines, with nothing from the web framework's generator.

## Requirements

### Requirement: Maya identity on the home page
The home page at `/` SHALL be public. Its header SHALL read "Maya" (a link to `/`) and SHALL have a link "Talk" to `/talk`. The page SHALL have exactly one top-level heading, "Your Pokédex has a voice now.", with id `home-heading`. The tagline "Maps, Answers, Yaps, Advice." SHALL be in `#home-tagline` and the line "So I hear you like Mudkip. Good. Correct choice." in `#home-catchphrase`. It SHALL NOT show the Talk screen (`#talk-screen`) or the Talk heading `#talk-heading`.

#### Scenario: Visitor opens the home page
- **WHEN** a visitor requests `/`
- **THEN** the response is HTTP 200
- **AND** the header link to `/` reads "Maya" and the header has a link `#header-talk-link` reading "Talk" to `/talk`
- **AND** the page has one `h1`, `#home-heading`, reading "Your Pokédex has a voice now."
- **AND** the page does not contain "Ask out loud. No spoilers."
- **AND** `#home-tagline` reads "Maps, Answers, Yaps, Advice."
- **AND** `#home-catchphrase` reads "So I hear you like Mudkip. Good. Correct choice."
- **AND** the page has no `#talk-screen`, no `#talk-heading` and no `#talk-button`

#### Scenario: Way in to the Talk screen
- **WHEN** a visitor requests `/`
- **THEN** the page has a link `#talk-link` reading "Talk to Maya" to `/talk`

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
The home page SHALL NOT load images, video, captions, fonts, stylesheets or scripts from any host other than its own, and SHALL NOT contain `iframe`, `embed` or `video` elements. Its backdrops SHALL be CSS backgrounds from `/images/backdrops/`, so the page has no `img` element.

#### Scenario: Only own assets
- **WHEN** a visitor requests `/`
- **THEN** every `src`, `poster` and stylesheet `href` on the page is a relative path
- **AND** the page contains no `iframe`, no `embed`, no `video` and no `img` element

#### Scenario: Backdrops from own origin
- **WHEN** the homepage block of `assets/css/app.css` is read
- **THEN** every `url()` in it starts with `/images/backdrops/` or `/fonts/`

### Requirement: Hero
The home page SHALL open with a hero `#home-hero`: the tide backdrop by day and the night backdrop at night, full bleed, at full strength at the top and fading into the page background below, then the eyebrow "A Pokémon Emerald companion", the heading, one line of body copy, the call to action `#talk-link` as a pill, and the mic note `#mic-note`. The heading SHALL use the heading font in italic, weight 600, at about 52px on a 375px wide screen. The hero SHALL hold no `img` and no ball.

#### Scenario: Hero parts
- **WHEN** a visitor requests `/`
- **THEN** `#home-hero` contains `#home-eyebrow` reading "A Pokémon Emerald companion", `#home-heading`, `#talk-link` and `#mic-note`
- **AND** `#mic-note` reads "The mic is on while you hold, and off a few seconds after."
- **AND** `#home-hero` contains no `img` and no `#pokeball`

#### Scenario: Backdrop per theme
- **WHEN** `/` renders with `data-theme="light"` and again with `data-theme="dark"`
- **THEN** the computed background image of `#home-hero` uses `/images/backdrops/tide.jpg` and `/images/backdrops/night.jpg` respectively

#### Scenario: Hero size on a phone
- **WHEN** `/` renders at 375px wide
- **THEN** `#home-hero` is between 500 and 620px tall
- **AND** `#home-heading` has a computed font size between 48 and 56px, `font-style` italic, `font-weight` 600 and a font family starting with "Fraunces"

#### Scenario: More art, fading at the bottom
- **WHEN** `/` renders at 375px wide in either theme
- **THEN** the fade over the art is fully transparent for at least the top 96px of `#home-hero`
- **AND** it reaches opaque `--maya-bg` no less than 144px from the top of `#home-hero` and at or above the top of `#home-eyebrow`, so all hero text sits on `--maya-bg`

### Requirement: Voice loop section
The home page SHALL have a section `#voice-loop` headed "How a turn works", showing the loop as four numbered steps `.loop-step`: "Hold", "Transcribe", "Agent with tools", "Speak", each on a line separated by a hairline rule, with no boxed cards and no image file. It SHALL show per-stage latency numbers only once they are measured on the phone and recorded in the repo; until then it SHALL show the note `#latency-pending` and no millisecond or second figures.

#### Scenario: Four steps in order
- **WHEN** a visitor requests `/`
- **THEN** `#voice-loop` has an ordered list of 4 `.loop-step` elements reading "Hold", "Transcribe", "Agent with tools" and "Speak" in that order

#### Scenario: Ruled lines, no cards
- **WHEN** `/` renders
- **THEN** each step line in `#voice-loop` has a computed top or bottom border and no box shadow and no background other than transparent

#### Scenario: No invented latency
- **WHEN** a visitor requests `/` and no phone latency numbers are recorded in the repo
- **THEN** `#latency-pending` exists
- **AND** the text of `#voice-loop` matches no number followed by "ms" or "s"

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

### Requirement: Spoiler promise band
The home page SHALL have a band `#spoiler-promise` on the sea background with the heading "Further ahead, no spoilers." in the heading font and one item `#promise-ci-gate` about the CI spoiler gate. The CI gate item SHALL say the gate is planned until the CI workflow has a spoiler gate job (#40), and SHALL NOT claim it runs before then.

#### Scenario: Promise band
- **WHEN** a visitor requests `/`
- **THEN** `#spoiler-promise` has a heading reading "Further ahead, no spoilers." and `#promise-ci-gate` with non-empty text
- **AND** the computed background colour of `#spoiler-promise` is that theme's `--maya-sea`

#### Scenario: Gate wording stays honest
- **WHEN** a visitor requests `/` and `.github/workflows/ci.yml` has no job whose id contains "spoiler"
- **THEN** `#promise-ci-gate` contains the word "planned"

#### Scenario: Homepage stays spoiler-free
- **WHEN** a visitor requests `/`
- **THEN** the page names none of the Hoenn gym leaders after Roxanne (Brawly, Wattson, Flannery, Norman, Winona, Tate, Liza, Juan)
- **AND** no evolved form of a Hoenn starter (Grovyle, Sceptile, Combusken, Blaziken, Marshtomp, Swampert)

### Requirement: A real turn on the homepage
The home page SHALL have a section `#real-turn` showing one real turn from Maya at Route 104: the Question `#real-turn-question` small, right aligned and in the muted colour, and the Answer `#real-turn-answer` as unboxed text at about 24px. A caption `#real-turn-latency` SHALL give the median Answer time and the turn count it covers, both taken from one recorded value in the code.

#### Scenario: Real turn shown
- **WHEN** a visitor requests `/`
- **THEN** `#real-turn-question` reads "Where do I go next?" and `#real-turn-answer` reads "Head north to Rustboro City for Roxanne. Mudkip's Water moves make it a short fight."
- **AND** `#real-turn-answer` contains no element with a background or border
- **AND** `#real-turn-latency` reads "Median Answer time 4.95 s over 145 turns"

#### Scenario: Caption follows the recorded value
- **WHEN** the recorded median is changed to 4.20 s over 200 turns
- **THEN** `#real-turn-latency` reads "Median Answer time 4.20 s over 200 turns" with no other edit

#### Scenario: Answer size
- **WHEN** `/` renders at 375px wide
- **THEN** `#real-turn-answer` has a computed font size between 22 and 26px and the body font, and `#real-turn-question` a smaller size and the computed colour of `--maya-muted`

### Requirement: Meet Maya
The home page SHALL have a section `#meet-maya` headed "Meet Maya. She has opinions." with the Emerald ball `#pokeball.pokeball-emerald` (drawn in CSS, no image) as her avatar, the speech bubble `#home-catchphrase` and the tagline `#home-tagline`.

#### Scenario: Meet Maya parts
- **WHEN** a visitor requests `/`
- **THEN** `#meet-maya` contains a heading reading "Meet Maya. She has opinions.", `#pokeball.pokeball-emerald`, `#home-catchphrase` and `#home-tagline`
- **AND** `#pokeball` contains no `img` element

### Requirement: Maya's Dials as a description
`#meet-maya` SHALL show Maya's five Dials in `#dials` as read-only bars, each `.dial` with its name and value as text: humor 75, honesty 90, sass 40, Mudkip hype 100 and spoilers 0 marked locked. The bars describe her and SHALL NOT be controls: no form field, button, slider or copy inviting the visitor to change them.

#### Scenario: Five Dials, read only
- **WHEN** a visitor requests `/`
- **THEN** `#dials` has 5 `.dial` elements whose text reads "Humor 75", "Honesty 90", "Sass 40", "Mudkip hype 100" and "Spoilers 0, locked" in that order
- **AND** `#dials` contains no `input`, `button`, `select`, `form` or `[role=slider]` element
- **AND** the text of `#meet-maya` does not contain "change" or "ask her"

#### Scenario: Values match her prompt
- **WHEN** the Dial values on the homepage are compared with the Dials in Maya's agent prompt and the seed humor
- **THEN** every value is the same

### Requirement: Things she says
`#meet-maya` SHALL show a list `#sayings` of exactly 3 `.saying` bubbles in this order: "Mudkip would approve." and "Further ahead, no spoilers.", both lines from Maya's agent prompt, and "Mudkip is a pure Water type, and Maya is not biased at all.", her Mudkip hype line approved by Abhishek on 2026-11-15.

#### Scenario: Three real lines
- **WHEN** a visitor requests `/`
- **THEN** `#sayings` has 3 `.saying` elements reading "Mudkip would approve.", "Further ahead, no spoilers." and "Mudkip is a pure Water type, and Maya is not biased at all." in that order
- **AND** the first two appear word for word in `lib/maya/agent/prompt.ex`
