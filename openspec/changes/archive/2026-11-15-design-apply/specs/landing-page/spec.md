## ADDED Requirements

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
