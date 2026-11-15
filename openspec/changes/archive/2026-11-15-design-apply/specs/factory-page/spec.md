## ADDED Requirements

### Requirement: Factory page follows the design system

The `/factory` page SHALL take every colour, font, radius, shadow and transition from the Maya design tokens and SHALL follow the active theme, with headings in the heading font and tables and body copy in the body font.

#### Scenario: Factory page in both themes

- **WHEN** `/factory` renders with `data-theme="light"` and again with `data-theme="dark"`
- **THEN** the page background computes to that theme's `--maya-bg`, and the `h1` computed font family starts with "Fraunces"

#### Scenario: No purple left

- **WHEN** `/factory` renders in either theme
- **THEN** no element's computed colour, background or border colour is the Phoenix default purple (`oklch(58% 0.233 277.117)`)
