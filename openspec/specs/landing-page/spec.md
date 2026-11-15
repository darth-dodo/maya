# landing-page Specification

## Purpose

What a visitor sees at the site root before any Maya feature exists: Maya's name and tagline, and nothing from the web framework's generator.

## Requirements

### Requirement: Maya identity on the home page
The home page SHALL show the heading "Maya" in the element with id `maya-heading` and the tagline "Maps, Answers, Yaps, Advice. Your spoiler-free Pokémon Emerald companion." in the element with id `tagline`.

#### Scenario: Visitor opens the home page
- **WHEN** a visitor requests `/`
- **THEN** the response is HTTP 200
- **AND** the page contains a top-level heading with the text "Maya"
- **AND** the page contains the text "Maps, Answers, Yaps, Advice. Your spoiler-free Pokémon Emerald companion."
- **AND** the element `#maya-heading` has the text "Maya"
- **AND** the element `#tagline` has the text "Maps, Answers, Yaps, Advice. Your spoiler-free Pokémon Emerald companion."

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

### Requirement: Poké Ball themed hero
The home page SHALL show an Emerald edition Poké Ball (green, white and black) drawn in CSS without images, in an element with id `pokeball` and class `pokeball-emerald`, inside a hero with id `maya-hero` whose background is the calm tide backdrop served from `/images/backdrops/tide.jpg`.

#### Scenario: Poké Ball is present
- **WHEN** a visitor requests `/`
- **THEN** the element `#pokeball` exists
- **AND** it contains no `img` element

#### Scenario: Emerald ball on the tide backdrop
- **WHEN** a visitor requests `/`
- **THEN** `#pokeball` has the class `pokeball-emerald`
- **AND** `#maya-hero` has `data-backdrop="tide"`

### Requirement: Backdrop images
Maya SHALL serve three backdrop images (tide, dusk, night) from its own origin under `/images/backdrops/`. They are original scenery generated with Gemini and contain no Pokémon, people, text or logos.

#### Scenario: Backdrops are served
- **WHEN** a visitor requests `/images/backdrops/tide.jpg`, `/images/backdrops/dusk.jpg` or `/images/backdrops/night.jpg`
- **THEN** the response is 200 with content type `image/jpeg`

### Requirement: Mudkip hype
The home page SHALL show the line "Mudkip hype: 100. Best starter, no debate." in the element with id `mudkip-hype`.

#### Scenario: Hype line
- **WHEN** a visitor requests `/`
- **THEN** the element `#mudkip-hype` has the text "Mudkip hype: 100. Best starter, no debate."

### Requirement: Spoiler-free badge case
The home page SHALL show, while the Conversation is empty, a badge case with id `badge-case` holding exactly 8 badge slots, each marked as not earned and labelled only by its number, and SHALL NOT name any gym, gym leader or badge. Once the Conversation has a turn, the badge case is not shown.

#### Scenario: Eight empty slots
- **WHEN** a visitor requests `/` and the Conversation is empty
- **THEN** `#badge-case` contains exactly 8 elements with class `badge-slot`
- **AND** every slot has `data-earned="false"`
- **AND** the slots are labelled "Badge 1 of 8" through "Badge 8 of 8"

#### Scenario: No spoilers
- **WHEN** a visitor requests `/`
- **THEN** the page contains none of the Hoenn gym leader names (Roxanne, Brawly, Wattson, Flannery, Norman, Winona, Tate, Liza, Juan)
- **AND** none of the Hoenn badge names (Stone, Knuckle, Dynamo, Heat, Balance, Feather, Mind, Rain) followed by "Badge"

#### Scenario: Hidden once the Conversation starts
- **WHEN** a visitor requests `/` and the Conversation has a turn
- **THEN** the page has no `#badge-case`

### Requirement: Original art only
The home page SHALL NOT load images, fonts, stylesheets or scripts from any host other than its own, and SHALL NOT contain `img` elements.

#### Scenario: Only own assets
- **WHEN** a visitor requests `/`
- **THEN** every `src` and stylesheet `href` on the page is a relative path
- **AND** the page contains no `img` element

### Requirement: Rotating Poké facts
While the Conversation is empty, the home page SHALL show a list `#poke-facts` of 10 to 14 spoiler-free `.poke-fact` items in the server-rendered HTML, naming only the Hoenn starters and wild Pokémon before the first gym, never an evolved starter. The rotation SHALL be CSS only, with no script in the page content and no animation under reduced motion. Once the Conversation has a turn, the facts are not shown.

#### Scenario: Facts are listed
- **WHEN** a visitor requests `/` and the Conversation is empty
- **THEN** the element `#poke-facts` exists
- **AND** it contains between 10 and 14 elements with class `poke-fact`
- **AND** every `.poke-fact` has non-empty text

#### Scenario: Facts stay spoiler-free
- **WHEN** a visitor requests `/`
- **THEN** the "No spoilers" scenario of the badge case still holds for the whole page, facts included
- **AND** no `.poke-fact` names an evolved form of a Hoenn starter (Grovyle, Sceptile, Combusken, Blaziken, Marshtomp, Swampert)

#### Scenario: No script for the rotation
- **WHEN** a visitor requests `/`
- **THEN** the page content (`main`) contains no `script` element

#### Scenario: Facts hidden once the Conversation starts
- **WHEN** a visitor requests `/` and the Conversation has a turn
- **THEN** the page has no `#poke-facts`
