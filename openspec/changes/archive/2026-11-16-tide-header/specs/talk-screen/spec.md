# Spec Delta

## MODIFIED Requirements

### Requirement: Talk heading
The Talk screen SHALL have exactly one top-level heading, "Talk to Maya", with id `talk-heading`, visually hidden so it does not repeat the header, a header link "Maya" to `/` and a header link "Home" to `/`.

#### Scenario: Heading on the Talk screen
- **WHEN** a Guest opens `/talk`
- **THEN** the page has one `h1`, `#talk-heading`, reading "Talk to Maya"
- **AND** the header link to `/` reads "Maya"
- **AND** `#header-home-link` reads "Home" and links to `/`
