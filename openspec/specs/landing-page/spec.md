# landing-page Specification

## Purpose

What a visitor sees at the site root before any Maya feature exists: Maya's name and tagline, and nothing from the web framework's generator.

## Requirements

### Requirement: Maya identity on the home page
The home page SHALL show the heading "Maya" and the tagline "Maps, Answers, Yaps, Advice. Your spoiler-free Pokemon Emerald companion."

#### Scenario: Visitor opens the home page
- **WHEN** a visitor requests `/`
- **THEN** the response is HTTP 200
- **AND** the page contains a top-level heading with the text "Maya"
- **AND** the page contains the text "Maps, Answers, Yaps, Advice. Your spoiler-free Pokemon Emerald companion."

### Requirement: No framework marketing on the home page
The home page SHALL NOT show web framework generator content: marketing copy, framework documentation or repository links, or framework names in the page title.

#### Scenario: Generator content is gone
- **WHEN** a visitor requests `/`
- **THEN** the page does not contain the text "Peace of mind from prototype to production"
- **AND** the page does not contain "Phoenix Framework"
- **AND** the page does not link to `github.com/phoenixframework`

#### Scenario: Browser tab title
- **WHEN** a visitor requests `/`
- **THEN** the HTML title is "Maya"
