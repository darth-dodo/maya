## ADDED Requirements

### Requirement: Moves a Pokémon learns
The agent SHALL offer a `move_learnset` tool with one required string argument `species`. It SHALL return `{:ok, fact}` with the species name, the level horizon and its level-up moves (move, level, method) at or below the level horizon in level order; `{:error, :not_found}` for a species not in Maya's data; and `{:error, :past_horizon}` for a species with no wild place inside the Spoiler horizon that is not on the Team. No move above the level horizon SHALL reach the model.

#### Scenario: Mudkip at 0 badges
- **WHEN** Progress has 0 badges and a Team of Mudkip at level 5, and `move_learnset` is called for "Mudkip"
- **THEN** the Fact lists Tackle 1, Growl 1, Mud-Slap 6, Water Gun 10 and Bide 15 with method level-up
- **AND** it lists no move learned above level 15, such as Foresight at 19

#### Scenario: Species past the horizon
- **WHEN** Progress has 0 badges and a Team of Mudkip, and `move_learnset` is called for "Groudon"
- **THEN** it returns `past_horizon` and no move

#### Scenario: Unknown species
- **WHEN** `move_learnset` is called for "Agumon"
- **THEN** it returns `not_found`

#### Scenario: Missing argument
- **WHEN** `move_learnset` is called without `species`
- **THEN** it returns `bad_arguments` and the loop does not crash

#### Scenario: Every badge earned
- **WHEN** Progress has all 8 badges and `move_learnset` is called for "Mudkip"
- **THEN** the Fact lists every level-up move, including Endeavor

### Requirement: Move rule in the system prompt
The system prompt SHALL tell the model to call `move_learnset` before naming a move a Pokémon learns, and never to name a move the tool did not return in this turn.

#### Scenario: Prompt names the move tool
- **WHEN** the system prompt is built for any Progress
- **THEN** it contains `move_learnset` and the rule never to name a move it did not return
- **AND** it contains neither "beat" nor "defeat"

### Requirement: Move probe cases
The spoiler probe set SHALL gain move cases beyond the 20 Sunday goal Questions, each with its tool call, for Progress at 0 badges and a Team of Mudkip: "What will Mudkip learn next?" (a Fact with no move above level 15), "What moves does Groudon learn?" and "What does Marshtomp learn?" (both `past_horizon`). Mudkip's moves above level 15 SHALL be in the forbidden list for its case.

#### Scenario: Move probes pass the spoiler gate
- **WHEN** the move cases run through the agent with the model stubbed
- **THEN** Groudon and Marshtomp give `past_horizon`, Mudkip gives a Fact
- **AND** no Mudkip move above level 15 appears in any message sent to the model

### Requirement: Move tool latency
Adding `move_learnset` SHALL keep Answer time p95 at most 8 s, and its build PR SHALL show agent-stage p50 and p95 from `mix maya.latency` before and after.

#### Scenario: Latency before and after
- **WHEN** 10 Questions run on the phone before and after the change
- **THEN** the PR lists agent-stage p50 and p95 for both runs
- **AND** Answer time p95 after the change is at most 8 s
