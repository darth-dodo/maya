## ADDED Requirements

### Requirement: Trainers on a place
The agent SHALL offer a `find_trainer` tool with one required string argument `place`. It SHALL return `{:ok, fact}` with the place and each trainer's name and first party (species and levels) when the place is listed and inside the Spoiler horizon, and `{:error, :past_horizon}` when the place is past the horizon or not listed. A rematch party SHALL never be returned.

#### Scenario: Route 102 at 0 badges
- **WHEN** Progress has 0 badges and `find_trainer` is called for "Route 102"
- **THEN** the Fact lists Calvin with Poochyena at level 5
- **AND** it does not list Mightyena or any level above 15

#### Scenario: Place past the horizon
- **WHEN** Progress has 0 badges and `find_trainer` is called for "Route 110" or "Dewford Town"
- **THEN** it returns `past_horizon` with a hint naming no place

### Requirement: Where to get an item
The agent SHALL offer a `find_item` tool with one required string argument `name`. It SHALL return `{:ok, fact}` with each place inside the Spoiler horizon where the item is found, hidden, sold or given (place and how); `{:error, :past_horizon}` for a known item with no such place; and `{:error, :not_found}` for a name that is not an item in Maya's data. A gift SHALL be returned only from `gifts.json` and only when its `badges_required` is at most the badges earned.

#### Scenario: An item inside the horizon
- **WHEN** Progress has 0 badges and `find_item` is called for an item whose only row is a ball on Route 102
- **THEN** the Fact lists Route 102 with how `ball`

#### Scenario: Surf before badge 5
- **WHEN** Progress has 0 badges and `find_item` is called for "HM03"
- **THEN** it returns `past_horizon` and no place, including no Petalburg City

#### Scenario: Not an item
- **WHEN** `find_item` is called for "Master Sword"
- **THEN** it returns `not_found`

### Requirement: Team readiness for the Next gym
The agent SHALL offer a `team_check` tool with no arguments. It SHALL return `{:ok, fact}` with the Next gym leader, the ace's species, level and types, each Team member's level, level gap to the ace and best type multiplier against the ace, and `ready`: true when any member is at or above the ace's level, or has a multiplier of 2 or more and is at most 3 levels below the ace. With all 8 badges it SHALL return a Fact with no Next gym and the hint. It SHALL never name a gym past the Next gym.

#### Scenario: Mudkip at level 5 before Roxanne
- **WHEN** Progress has 0 badges and a Team of Mudkip at level 5
- **THEN** the Fact names Roxanne and Nosepass at level 15, Mudkip with level gap minus 10 and multiplier 2, and `ready` false

#### Scenario: Mudkip at level 13 before Roxanne
- **WHEN** Progress has 0 badges and a Team of Mudkip at level 13
- **THEN** `ready` is true

#### Scenario: Empty Team
- **WHEN** Progress has 0 badges and an empty Team
- **THEN** the Fact has no Team members and `ready` false

### Requirement: Trainer, item and readiness rules in the system prompt
The system prompt SHALL tell the model to call `find_trainer` for trainers on a place, `find_item` for where to get an item, and `team_check` when the player asks whether the Team is ready, and to state only what those tools return.

#### Scenario: Prompt names the three tools
- **WHEN** the system prompt is built for any Progress
- **THEN** it contains `find_trainer`, `find_item` and `team_check`
- **AND** it contains neither "beat" nor "defeat"

### Requirement: Trainer, item and readiness probe cases
The spoiler probe set SHALL gain cases beyond the 20 Sunday goal Questions, for Progress at 0 badges and a Team of Mudkip: "Who battles me on Route 110?" (`find_trainer`, `past_horizon`), "Where do I get Surf?" and "Where is the Mach Bike?" (`find_item`, both `past_horizon`), "Who is on Route 102?" (a Fact with no rematch party) and "Is my Team ready?" (`team_check`, naming no leader but Roxanne).

#### Scenario: Probes pass the spoiler gate
- **WHEN** the five cases run through the agent with the model stubbed
- **THEN** each gives its expected result and no forbidden name appears in any message sent to the model

### Requirement: Trainer and item tool latency
Adding the three tools SHALL keep Answer time p95 at most 8 s, and the build PR SHALL show agent-stage p50 and p95 from `mix maya.latency` before and after.

#### Scenario: Latency before and after
- **WHEN** 10 Questions run on the phone before and after the change
- **THEN** the PR lists agent-stage p50 and p95 for both runs
- **AND** Answer time p95 after the change is at most 8 s
