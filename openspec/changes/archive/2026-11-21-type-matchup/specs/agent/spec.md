## ADDED Requirements

### Requirement: Type matchups
The agent SHALL offer a `type_matchup` tool with `defender` (a type, a Pokémon, or a gym leader meaning the leader's ace) and an optional `attacker` type. With `attacker` it SHALL return the multiplier on the defender's types (the product for two types). Without it, the types at 2 or more and the types to avoid at 0.5 and 0. Multipliers SHALL come only from Maya's type chart; each pair SHALL carry its reason line when one exists.

#### Scenario: Water on Fire
- **WHEN** `type_matchup` is called with attacker "water" and defender "fire"
- **THEN** the Fact has multiplier 2 and the reason line for Water on Fire

#### Scenario: Dual type
- **WHEN** Progress has 0 badges and `type_matchup` is called with attacker "water" and defender "Geodude"
- **THEN** the Fact names Geodude as Rock and Ground with multiplier 4

#### Scenario: Zero
- **WHEN** `type_matchup` is called with attacker "electric" and defender "ground"
- **THEN** the Fact has multiplier 0 and the reason line for Electric on Ground

#### Scenario: Good against a gym ace
- **WHEN** Progress has 0 badges and `type_matchup` is called with defender "Roxanne"
- **THEN** the Fact names Nosepass as Rock, with Water, Grass, Fighting, Ground and Steel at 2 and Normal, Fire, Flying and Poison to avoid at 0.5

#### Scenario: No Fairy
- **WHEN** `type_matchup` is called with defender "fairy"
- **THEN** it returns `not_found`

### Requirement: Type matchups inside the Spoiler horizon
`type_matchup` SHALL return `past_horizon` for a gym leader past the Next gym, and for a Pokémon the player cannot meet inside the horizon: not on the Team, not in a wild place inside it and not in the party of a gym inside it. A type alone SHALL never be `past_horizon`.

#### Scenario: A later leader
- **WHEN** Progress has 0 badges and `type_matchup` is called with defender "Wattson"
- **THEN** it returns `past_horizon` and names no Pokémon

#### Scenario: A Pokémon met only later
- **WHEN** Progress has 0 badges and `type_matchup` is called with defender "Magneton"
- **THEN** it returns `past_horizon`

### Requirement: Type matchup rule in the system prompt
The system prompt SHALL tell the model to call `type_matchup` when the player asks what is good against, what to avoid against, or why a type is weak to another, to say the multiplier first and the reason line only as flavour, and to state nothing it did not return.

#### Scenario: Prompt names the tool
- **WHEN** the system prompt is built for any Progress
- **THEN** it contains `type_matchup`
- **AND** it contains neither "beat" nor "defeat"

### Requirement: Type matchup is a read
A `type_matchup` result SHALL back Facts only: an Answer that claims a write SHALL be rejected when `type_matchup` is the only tool that ran this turn.

#### Scenario: Read cited for a write claim
- **WHEN** only `type_matchup` ran and the Answer says something was logged
- **THEN** the honesty check rejects it and one corrective request is sent

### Requirement: Type matchup probe cases
The spoiler probe set SHALL gain type matchup cases at 0 and 2 badges, each with the forbidden names for its badge count.

#### Scenario: Probes at 0 badges
- **WHEN** Progress has 0 badges, and "What is good against Roxanne?", "Why is Fire weak to Water?", "What is good against Wattson?" and "What is Magneton weak to?" run with the model stubbed
- **THEN** the first two return Facts, the last two `past_horizon`
- **AND** no forbidden name appears in any message sent to the model

#### Scenario: Wattson at 2 badges
- **WHEN** Progress has badges 1 and 2, and "What is good against Wattson?" runs
- **THEN** the Fact names Wattson's ace from Maya's trainer data and Ground at 2 or more
- **AND** no message sent to the model names Flannery or Lavaridge

### Requirement: Type matchup latency
Adding `type_matchup` SHALL keep Answer time p95 at most 8 s, and the build PR SHALL show the agent request size in bytes and agent-stage p50 and p95 from `mix maya.latency` before and after.

#### Scenario: Latency and size before and after
- **WHEN** 10 Questions run on the phone before and after the change
- **THEN** the PR lists request bytes and agent-stage p50 and p95 for both runs
- **AND** Answer time p95 after the change is at most 8 s
