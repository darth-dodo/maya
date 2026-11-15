## ADDED Requirements

### Requirement: No Fact for a Pokémon met only past the horizon
`find_pokemon` SHALL return `past_horizon` for a species with no wild place inside the Spoiler horizon, including a species with no wild places at all (a gift, legendary or fossil Pokémon), unless the species is on the player's Team.

#### Scenario: Legendary Pokémon at 0 badges
- **WHEN** Progress has 0 badges and a Team of Mudkip, and `find_pokemon` is called for "Groudon"
- **THEN** it returns `past_horizon` and no part of Groudon's types or evolutions

#### Scenario: Gift Pokémon at 0 badges
- **WHEN** Progress has 0 badges and a Team of Mudkip, and `find_pokemon` is called for "Beldum"
- **THEN** it returns `past_horizon`

#### Scenario: A Team member with no wild places
- **WHEN** Progress has a Team of Mudkip and `find_pokemon` is called for "Mudkip"
- **THEN** it returns a Fact with Mudkip's types and no places

### Requirement: Spoiler probe set
A committed probe set SHALL hold 20 Questions for Progress at 0 badges, each with the tool call it leads to, and one forbidden list: gym leaders, badges, cities, routes and places past Rustboro, and the probed Pokémon. It SHALL include gift and legendary Pokémon.

#### Scenario: Every probe is past the horizon
- **WHEN** each probe's tool call runs through the agent with Progress at 0 badges and the model stubbed
- **THEN** its tool result is `past_horizon` with a hint

#### Scenario: No forbidden name reaches the model
- **WHEN** the 20 probes run through the agent with the model stubbed
- **THEN** no forbidden name, in any letter case, appears in a system or tool message sent to the model

### Requirement: Roxanne then Ralts in one Conversation
With Progress at 0 badges and a Team of Mudkip, "How do I earn Roxanne's badge?" then "Where do I catch a Ralts?" in the same Conversation SHALL each get a Fact from a tool, and the second request SHALL carry the first turn.

#### Scenario: Sunday Questions with the model stubbed
- **WHEN** the two Questions are asked in order, the stubbed model calling `gym_counter` for Roxanne and then `find_pokemon` for Ralts
- **THEN** the first tool result names Nosepass as Roxanne's ace and Mudkip as the suggested lead
- **AND** the second tool result lists Route 102
- **AND** the second request has the first Question and Answer before the second Question
