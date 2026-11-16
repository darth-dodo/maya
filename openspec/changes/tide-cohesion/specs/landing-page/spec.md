# Spec Delta

## MODIFIED Requirements

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

### Requirement: Hero
The home page SHALL open with a hero `#home-hero`: the tide backdrop by day and the night backdrop at night, full bleed, shown at full strength at the top and fading into the page background towards the bottom, then the eyebrow "A Pokémon Emerald companion", the heading, one line of body copy, the call to action `#talk-link` as a pill, and the mic note `#mic-note`. The heading SHALL use the heading font in italic, weight 600, at about 52px on a 375px wide screen. The hero SHALL hold no `img` and no ball.

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
