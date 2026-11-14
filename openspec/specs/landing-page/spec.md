# landing-page Specification

## Purpose

What a visitor sees at the site root before any Maya feature exists: Maya's name and tagline, and nothing from the web framework's generator.

## Requirements

### Requirement: Maya identity on the home page
The home page SHALL show the heading "Maya" in the element with id `maya-heading` and the tagline "Maps, Answers, Yaps, Advice. Your spoiler-free Pokemon Emerald companion." in the element with id `tagline`.

#### Scenario: Visitor opens the home page
- **WHEN** a visitor requests `/`
- **THEN** the response is HTTP 200
- **AND** the page contains a top-level heading with the text "Maya"
- **AND** the page contains the text "Maps, Answers, Yaps, Advice. Your spoiler-free Pokemon Emerald companion."
- **AND** the element `#maya-heading` has the text "Maya"
- **AND** the element `#tagline` has the text "Maps, Answers, Yaps, Advice. Your spoiler-free Pokemon Emerald companion."

### Requirement: No framework marketing on the home page
The home page, including the app layout around it, SHALL NOT show web framework generator content: marketing copy, framework documentation or repository links, framework logos or version numbers, or framework names in the page title.

#### Scenario: Generator content is gone
- **WHEN** a visitor requests `/`
- **THEN** the page does not contain the text "Peace of mind from prototype to production"
- **AND** the page does not contain "Phoenix Framework"
- **AND** the page does not link to `github.com/phoenixframework`
- **AND** the page does not link to `phoenixframework.org` or `hexdocs.pm`

#### Scenario: Browser tab title
- **WHEN** a visitor requests `/`
- **THEN** the HTML title is "Maya"

### Requirement: Poke Ball themed hero
The home page SHALL show an Emerald edition Poke Ball (green, white and black) drawn in CSS without images, in an element with id `pokeball` and class `pokeball-emerald`, inside a hero with id `maya-hero` whose background is the calm tide backdrop served from `/images/backdrops/tide.jpg`.

#### Scenario: Poke Ball is present
- **WHEN** a visitor requests `/`
- **THEN** the element `#pokeball` exists
- **AND** it contains no `img` element

#### Scenario: Emerald ball on the tide backdrop
- **WHEN** a visitor requests `/`
- **THEN** `#pokeball` has the class `pokeball-emerald`
- **AND** `#maya-hero` has `data-backdrop="tide"`

### Requirement: Backdrop images
Maya SHALL serve three backdrop images (tide, dusk, night) from its own origin under `/images/backdrops/`. They are original scenery generated with Gemini and contain no Pokemon, people, text or logos.

#### Scenario: Backdrops are served
- **WHEN** a visitor requests `/images/backdrops/tide.jpg`, `/images/backdrops/dusk.jpg` or `/images/backdrops/night.jpg`
- **THEN** the response is 200 with content type `image/jpeg`

### Requirement: Mudkip hype
The home page SHALL show the line "Mudkip hype: 100. Best starter, no debate." in the element with id `mudkip-hype`.

#### Scenario: Hype line
- **WHEN** a visitor requests `/`
- **THEN** the element `#mudkip-hype` has the text "Mudkip hype: 100. Best starter, no debate."

### Requirement: Spoiler-free badge case
The home page SHALL show a badge case with id `badge-case` holding exactly 8 badge slots, each marked as not earned and labelled only by its number, and SHALL NOT name any gym, gym leader or badge.

#### Scenario: Eight empty slots
- **WHEN** a visitor requests `/`
- **THEN** `#badge-case` contains exactly 8 elements with class `badge-slot`
- **AND** every slot has `data-earned="false"`
- **AND** the slots are labelled "Badge 1 of 8" through "Badge 8 of 8"

#### Scenario: No spoilers
- **WHEN** a visitor requests `/`
- **THEN** the page contains none of the Hoenn gym leader names (Roxanne, Brawly, Wattson, Flannery, Norman, Winona, Tate, Liza, Juan)
- **AND** none of the Hoenn badge names (Stone, Knuckle, Dynamo, Heat, Balance, Feather, Mind, Rain) followed by "Badge"

### Requirement: Original art only
The home page SHALL NOT load images, fonts, stylesheets or scripts from any host other than its own, and SHALL NOT contain `img` elements.

#### Scenario: Only own assets
- **WHEN** a visitor requests `/`
- **THEN** every `src` and stylesheet `href` on the page is a relative path
- **AND** the page contains no `img` element
