## ADDED Requirements

### Requirement: Talk screen follows the design system

The Talk screen SHALL take every colour, font, radius, shadow and transition from the Maya design tokens and SHALL follow the active theme: Calm Emerald by day and Emerald night at night, with the gold hairline on the trainer card and the glow on Maya's ball only at night. Headings and the gym line SHALL use the heading font; Answers, buttons and labels SHALL use the body font. Only state changes SHALL move.

#### Scenario: Night look

- **WHEN** `/talk` renders with `data-theme="dark"`
- **THEN** the screen background computes to the night `--maya-bg` (`#08181a`), the trainer card border colour computes to the gold hairline (`#b58a2a`), and Maya's ball has a box shadow glow

#### Scenario: Day look

- **WHEN** `/talk` renders with `data-theme="light"`
- **THEN** the screen background computes to the day `--maya-bg` (`#f6f1e7`), the Talk button background computes to `--maya-action` (`#0f5a3a`), and the card has no gold border

#### Scenario: Fonts on the Talk screen

- **WHEN** `/talk` renders in either theme
- **THEN** the Talk heading's computed font family starts with "Fraunces" and the latest Answer's starts with "Inter"

#### Scenario: Behaviour unchanged

- **WHEN** the existing Talk screen and voice loop tests run after the change
- **THEN** they all pass with no edits to their assertions about states, mic handling or the voice loop
