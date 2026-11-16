## ADDED Requirements

### Requirement: Walkthrough notes by location
The agent SHALL offer a `search_guide` tool with one optional string argument `location`, defaulting to the Guest's current location. It SHALL return `{:ok, fact}` with the location name and its note when the location is listed and inside the Spoiler horizon; `{:error, :past_horizon}` when the location is past the horizon or not listed; and `{:error, :not_found}` when a listed location inside the horizon has no note. The horizon SHALL be applied in the SQL query on `badges_required`.

#### Scenario: Current location
- **WHEN** Progress has 0 badges and location Littleroot Town, and `search_guide` is called with no arguments
- **THEN** the Fact is Littleroot Town's note

#### Scenario: Named place inside the horizon
- **WHEN** Progress has 0 badges and `search_guide` is called for "rustboro city"
- **THEN** the Fact is Rustboro City's note

#### Scenario: Dewford before badge 1
- **WHEN** Progress has 0 badges and `search_guide` is called for "Dewford Town"
- **THEN** it returns `past_horizon` with a hint naming Roxanne and no place

#### Scenario: Dewford after badge 1
- **WHEN** Progress has badge 1 and `search_guide` is called for "Dewford Town", "Granite Cave" or "Slateport City"
- **THEN** the Fact is that location's note

#### Scenario: Mauville before badge 2
- **WHEN** Progress has badge 1 and `search_guide` is called for "Route 110" or "Mauville City"
- **THEN** both return `past_horizon` with a hint naming Brawly and no place

#### Scenario: Mauville after badge 2
- **WHEN** Progress has badges 1 and 2 and `search_guide` is called for "Mauville City"
- **THEN** the Fact is Mauville City's note

#### Scenario: Unlisted or made-up place
- **WHEN** Progress has badges 1 and 2 and `search_guide` is called for "Verdanturf Town" or for "Narnia"
- **THEN** both return `past_horizon` with the same hint

### Requirement: Humor dial by voice
The agent SHALL offer a `set_setting` tool with required arguments `name` (enum `humor`) and `value` (integer). For humor 0 to 100 it SHALL write the Humor dial and return `{:logged, line, new_progress}` with the confirm "Humor set to <value> percent.", and the rest of the turn SHALL use the new Progress. Any other name, or a value out of range, SHALL return `{:refused, line}`.

#### Scenario: "Maya, humor 60 percent"
- **WHEN** Progress has humor 75 and the model calls `set_setting` with `{"name": "humor", "value": 60}`
- **THEN** the tool message is the confirm "Humor set to 60 percent."
- **AND** the Guest's Progress has humor 60

#### Scenario: Spoilers stay locked
- **WHEN** the model calls `set_setting` with `{"name": "spoilers", "value": 100}`
- **THEN** the tool message is a refused line saying spoilers stay at 0
- **AND** Progress is unchanged

#### Scenario: Value out of range
- **WHEN** the model calls `set_setting` with `{"name": "humor", "value": 140}`
- **THEN** the tool message is a refused line and humor is unchanged

### Requirement: Guide and Dial rules in the system prompt
The system prompt SHALL tell the model to call `search_guide` when the player asks where to go or what is in a place and to say only what its note says; to call `set_setting` when the player asks to change humor and to say its confirm or refused line; and never to say a Dial changed unless `set_setting` confirmed it in this turn.

#### Scenario: Prompt names the guide and Dial tools
- **WHEN** the system prompt is built for any Progress
- **THEN** it contains `search_guide`, `set_setting` and the rule never to say a Dial changed without a confirm
- **AND** it contains neither "beat" nor "defeat"

### Requirement: Guide and Dial probe cases
The spoiler probe set SHALL gain guide and Dial cases beyond the 20 Sunday goal Questions, at 0, 1 and 2 badges, each case with the forbidden names for its badge count, plus one honesty case for a claimed Dial change.

#### Scenario: Guide probes at 0 badges
- **WHEN** Progress has 0 badges and the cases "What is in Dewford Town?", "Where is Mauville City?", "I'm stuck, where now?" from Rustboro City and "Set spoilers to 100" run with the model stubbed
- **THEN** the first two return `past_horizon`, the third a Fact naming no place past Rustboro, the fourth a refused `set_setting`
- **AND** no forbidden name appears in any message sent to the model

#### Scenario: Nothing about Mauville at 1 badge
- **WHEN** Progress has badge 1 and location Dewford Town, and the cases "I'm stuck, where now?", "What is in Slateport City?" and "What is in Mauville City?" run
- **THEN** the first two are Facts naming no place past Slateport City and the third is `past_horizon`
- **AND** no message sent to the model names Mauville, Route 107, 108, 110 or Wattson

#### Scenario: Nothing past Mauville at 2 badges
- **WHEN** Progress has badges 1 and 2 and location Mauville City, and the case "What is next?" runs
- **THEN** the Fact names no place past Mauville City
- **AND** no message sent to the model names Verdanturf, Lavaridge, Route 111, Route 117 or Flannery

#### Scenario: Claimed Dial change without a tool call
- **WHEN** the stubbed model replies "Humor set to 60 percent." with no tool call in that turn
- **THEN** the honesty check flags the reply

### Requirement: Guide tool latency
Adding `search_guide` and `set_setting` SHALL keep Answer time p95 at most 8 s, and each build PR SHALL show agent-stage p50 and p95 from `mix maya.latency` before and after.

#### Scenario: Latency before and after
- **WHEN** 10 Questions run on the phone before and after the change
- **THEN** the PR lists agent-stage p50 and p95 for both runs
- **AND** Answer time p95 after the change is at most 8 s
