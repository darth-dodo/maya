# Spec Delta

## ADDED Requirements

### Requirement: Talk screen without containers
The Talk screen SHALL sit directly on the page: `#talk-screen` SHALL have no border, no corner radius and no background image, on a full bleed `--maya-bg`, and the trainer info `#trainer-card` SHALL have no border, no corner radius and no box shadow. The page SHALL not scroll sideways at 375px.

#### Scenario: No scene panel
- **WHEN** `/talk` renders at 375px wide with `data-theme="light"` and again with `data-theme="dark"`
- **THEN** `#talk-screen` has a computed border width of 0, a border radius of 0 and a background image of `none`
- **AND** the `body` background computes to that theme's `--maya-bg`

#### Scenario: No card box
- **WHEN** `/talk` renders in either theme
- **THEN** `#trainer-card` has a computed border width of 0 on every side, a border radius of 0 and a box shadow of `none`

#### Scenario: No sideways scroll
- **WHEN** `/talk` renders at 375px wide for a Guest with 6 Team members and 3 stored turns
- **THEN** the document scroll width is not larger than 375px

#### Scenario: Nothing changes size between moments
- **WHEN** `/talk` renders at 375px wide and `#talk-screen` `data-state` is set to `idle`, `recording`, `waiting` and `speaking` in turn
- **THEN** the computed heights of `#site-header`, `#trainer-card` and `#talk-button` are the same in every moment

## MODIFIED Requirements

### Requirement: Slim header over tide art
The trainer info `#trainer-card` SHALL sit in the same tide art band as the homepage hero, smaller: tide art by day and night art at night from `/images/backdrops/`, full strength at the top and fading into `--maya-bg`, so its text sits on `--maya-bg`. It SHALL show Maya's ball, about 60px, left of an eyebrow with the location and badge count and the Next gym line in the heading font, then the Team as chips that wrap.

#### Scenario: Header parts
- **WHEN** a new Guest opens `/talk`
- **THEN** `#trainer-card` contains `#location`, `#badge-count`, `#next-gym`, `#team`, `#badge-case` and `#pokeball`
- **AND** `#location` and `#badge-count` are inside one element `#card-eyebrow`

#### Scenario: Art per theme
- **WHEN** `/talk` renders with `data-theme="light"` and again with `data-theme="dark"`
- **THEN** the computed background image of `#trainer-card` uses `/images/backdrops/tide.jpg` and `/images/backdrops/night.jpg` respectively

#### Scenario: Art stays faint
- **WHEN** `/talk` renders at 375px wide in either theme
- **THEN** the fade over the art in `#trainer-card` reaches opaque `--maya-bg` at or above the top of `#card-eyebrow` and of `#pokeball`, written with tokens and no colour literal
- **AND** `#trainer-card` is shorter than `#home-hero` at the same width

#### Scenario: Ball beside the eyebrow
- **WHEN** `/talk` renders at 375px wide
- **THEN** `#pokeball` is between 56 and 64px wide and its right edge is left of the left edge of `#card-eyebrow`

#### Scenario: Eyebrow separator on older Safari
- **WHEN** the Talk block of `assets/css/app.css` is read
- **THEN** the rule that puts "·" before `#badge-count` declares a plain `content: "·";` before the `content: "·" / "";` line

#### Scenario: Team chips wrap
- **WHEN** `/talk` renders at 375px wide for a Guest with 6 Team members
- **THEN** `#team` has a computed `flex-wrap` of `wrap`, its scroll width is not larger than its client width, and the page has no horizontal scroll

### Requirement: Talk screen follows the design system

The Talk screen SHALL take every colour, font, radius, shadow and transition from the Maya design tokens and SHALL follow the active theme: Calm Emerald by day and Emerald night at night, with the glow on Maya's ball only at night and no gold hairline on the trainer info. Headings and the gym line SHALL use the heading font; Answers, buttons and labels SHALL use the body font. Only state changes SHALL move.

#### Scenario: Night look

- **WHEN** `/talk` renders with `data-theme="dark"`
- **THEN** the page background computes to the night `--maya-bg` (`#08181a`), `#trainer-card` has no bottom border, and Maya's ball has a box shadow glow

#### Scenario: Day look

- **WHEN** `/talk` renders with `data-theme="light"`
- **THEN** the page background computes to the day `--maya-bg` (`#f6f1e7`), the Talk button background computes to `--maya-action` (`#0f5a3a`), and `#trainer-card` has no border

#### Scenario: Fonts on the Talk screen

- **WHEN** `/talk` renders in either theme
- **THEN** the Talk heading's and `#next-gym`'s computed font families start with "Fraunces" and the latest Answer's starts with "Inter"

#### Scenario: Behaviour unchanged

- **WHEN** the existing Talk screen and voice loop tests run after the change
- **THEN** they all pass with no edits to their assertions about states, mic handling or the voice loop
- **AND** `assets/js/talk_hook.js` has no diff

### Requirement: Short chat
The chat SHALL show only the last 3 turns, unboxed on the page, styled like the homepage real turn: every Question small, right aligned and muted, every Answer on the left, with no bubble background or border and a `--maya-line` hairline between turns. Older Answers SHALL use the muted colour at body size; the latest turn is marked as current and its Answer is the largest text on the screen, about 24px. A Question of "(nothing heard)" SHALL read as a friendly line instead.

#### Scenario: Last three exchanges
- **WHEN** a Guest with 5 stored turns opens `/talk`
- **THEN** `#conversation` has 3 `.turn` elements, the last 3 in order, and only the last has the class `now`

#### Scenario: Nothing heard
- **WHEN** a stored turn has the Question "(nothing heard)"
- **THEN** its `.question` has the class `nothing-heard` and reads "Maya did not hear anything that time"

#### Scenario: Unboxed with hairlines
- **WHEN** `/talk` renders with 3 stored turns, in either theme
- **THEN** no `.question` or `.answer` has a computed background other than transparent, a border or a box shadow
- **AND** each `.turn` after the first has a computed top border in that theme's `--maya-line`

#### Scenario: Questions like the homepage
- **WHEN** `/talk` renders at 375px wide with 3 stored turns, in either theme
- **THEN** every `.question` is right aligned, has the computed colour of `--maya-muted` and the same computed font size as `#real-turn-question` on `/`

#### Scenario: Latest Answer largest
- **WHEN** `/talk` renders at 375px wide with 3 stored turns
- **THEN** `.turn.now .answer` has a computed font size between 22 and 26px, the colour of `--maya-ink`, larger than every other text on the screen except the gym line
- **AND** older `.answer` elements have the body size and the computed colour of `--maya-muted`
