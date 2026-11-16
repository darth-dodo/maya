# Spec Delta

## MODIFIED Requirements

### Requirement: Maya identity on the home page
The home page at `/` SHALL be public. Its header SHALL read "Maya" (a link to `/`) and SHALL have a link "Talk" to `/talk`. The page SHALL have exactly one top-level heading, "Ask out loud. No spoilers.", with id `home-heading`. The tagline "Maps, Answers, Yaps, Advice." SHALL be in `#home-tagline` and the line "So I hear you like Mudkip. Good. Correct choice." in `#home-catchphrase`. It SHALL NOT show the Talk screen (`#talk-screen`) or the Talk heading `#talk-heading`.

#### Scenario: Visitor opens the home page
- **WHEN** a visitor requests `/`
- **THEN** the response is HTTP 200
- **AND** the header link to `/` reads "Maya" and the header has a link `#header-talk-link` reading "Talk" to `/talk`
- **AND** the page has one `h1`, `#home-heading`, reading "Ask out loud. No spoilers."
- **AND** `#home-tagline` reads "Maps, Answers, Yaps, Advice."
- **AND** `#home-catchphrase` reads "So I hear you like Mudkip. Good. Correct choice."
- **AND** the page has no `#talk-screen`, no `#talk-heading` and no `#talk-button`

#### Scenario: Way in to the Talk screen
- **WHEN** a visitor requests `/`
- **THEN** the page has a link `#talk-link` reading "Talk to Maya" to `/talk`
