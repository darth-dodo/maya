## ADDED Requirements

### Requirement: Rotating Poke facts
The home page SHALL show a list with id `poke-facts` of between 10 and 14 short, spoiler-free Poke facts, each an element with class `poke-fact`, all present in the server-rendered HTML. Facts SHALL name only the Hoenn starters and wild Pokemon found before the first gym, and SHALL NOT name an evolved form of a Hoenn starter. The rotation SHALL be CSS only and SHALL NOT add a script to the page content; when reduced motion is requested there is no animation.

#### Scenario: Facts are listed
- **WHEN** a visitor requests `/`
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
