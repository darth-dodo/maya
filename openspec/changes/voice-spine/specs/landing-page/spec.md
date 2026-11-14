## MODIFIED Requirements

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

### Requirement: Rotating Poke facts
The home page SHALL show, while the Conversation is empty, a list with id `poke-facts` of between 10 and 14 short, spoiler-free Poke facts, each an element with class `poke-fact`, all present in the server-rendered HTML. Facts SHALL name only the Hoenn starters and wild Pokemon found before the first gym, and SHALL NOT name an evolved form of a Hoenn starter. The rotation SHALL be CSS only and SHALL NOT add a script to the page content; when reduced motion is requested there is no animation. Once the Conversation has a turn, the facts are not shown.

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
