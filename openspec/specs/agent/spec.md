# agent Specification

## Purpose
How Maya turns a Question into an Answer: a tool-calling loop over OpenRouter, tools that return Facts from Maya's own data inside the Spoiler horizon (ADR-004), and the rules every Answer follows.

## Requirements

### Requirement: Tool-calling agent loop
Maya SHALL answer a Question with a hand-written loop over OpenRouter chat completions. Every request SHALL include the tool definitions. When the model replies with `tool_calls`, Maya SHALL parse each call's `arguments` JSON string on its own, run the tool, and send back exactly one `role: "tool"` message per call carrying that call's `tool_call_id`. The loop SHALL stop when the model replies with text, and SHALL make at most 4 requests per Question. The model name SHALL come from config.

#### Scenario: Roxanne round trip
- **WHEN** Progress has 0 badges and a Team of Mudkip at level 5, the Question is "How do I earn Roxanne's badge?", and the model first calls `gym_counter` with `{"leader": "Roxanne"}` and then answers in text
- **THEN** the second request carries one tool message with the call's `tool_call_id` whose content names Roxanne's ace Nosepass at level 15 and suggests Mudkip as the lead
- **AND** both requests include the tool definitions and the configured model
- **AND** the Answer is the model's text

#### Scenario: Malformed arguments
- **WHEN** the model calls a tool with an `arguments` string that is not a JSON object
- **THEN** the loop does not crash
- **AND** the next request carries a tool message for that call saying the arguments were malformed

#### Scenario: Round cap
- **WHEN** the model replies with `tool_calls` to every request
- **THEN** Maya stops after 4 requests and returns an agent error

#### Scenario: OpenRouter error
- **WHEN** OpenRouter answers with an HTTP error or there is no API key
- **THEN** Maya returns an agent error without calling more tools

### Requirement: Tools return Facts inside the Spoiler horizon
`gym_counter(leader)` SHALL return the leader's team with levels and types, the player's Team with each member's best Gen 3 type multiplier against the leader's ace, and a suggested lead. `find_pokemon(name)` SHALL return the species' types, evolutions and wild encounter places with rates, keeping only places inside the Spoiler horizon. Each tool SHALL return a Fact, `not_found`, or `past_horizon`, and the horizon SHALL be applied before any result reaches the model.

#### Scenario: Gym counter for the Next gym
- **WHEN** Progress has 0 badges and a Team of Mudkip at level 5, and `gym_counter` is called for "Roxanne"
- **THEN** the Fact lists Geodude 12, Geodude 12 and Nosepass 15, names Nosepass as the ace, rates Mudkip's water type at 2x against Nosepass, and suggests Mudkip as the lead

#### Scenario: Gym leader past the horizon
- **WHEN** Progress has 0 badges and `gym_counter` is called for "Brawly"
- **THEN** it returns `past_horizon` and no part of Brawly's team

#### Scenario: Unknown leader or Pokémon
- **WHEN** `gym_counter` is called for "Professor Oak" or `find_pokemon` for "Agumon"
- **THEN** it returns `not_found`

#### Scenario: Pokémon inside the horizon
- **WHEN** Progress has 0 badges and `find_pokemon` is called for "Ralts"
- **THEN** the Fact has type psychic, evolution into Kirlia at level 20, and Route 102 land at 4 percent
- **AND** no place outside the horizon is listed

#### Scenario: Pokémon found only past the horizon
- **WHEN** Progress has 0 badges and `find_pokemon` is called for a species whose wild places are all past the horizon
- **THEN** it returns `past_horizon`

### Requirement: Answer rules in the system prompt
Every agent request SHALL start with a system prompt that states the Answer rules: game Facts only from tool results in this turn (ADR-004), never past the Spoiler horizon ("Further ahead, no spoilers" plus a hint that names no place), "Not sure" when no tool gives a Fact, 2 to 3 spoken sentences, the Dials, the Catchphrase and inclusive language. The prompt SHALL NOT contain the words "beat" or "defeat".

#### Scenario: Prompt carries the rules and Progress
- **WHEN** Progress has 0 badges, humor 75 and a Team of Mudkip at level 5
- **THEN** the system prompt names the Next gym Roxanne, the Team, humor 75, honesty 90, sass 40, spoilers 0, Mudkip hype 100, "Further ahead, no spoilers", "Not sure", "Mudkip would approve." and 2 to 3 sentences
- **AND** it contains neither "beat" nor "defeat"

### Requirement: Recent turns as context
Maya SHALL send the last 5 turns of the Conversation as context between the system prompt and the Question.

#### Scenario: Last 5 turns as context
- **WHEN** the Conversation has 7 stored turns and a new Question arrives
- **THEN** the request has the system prompt, the last 5 turns as user and assistant messages in order, then the Question

### Requirement: Model comparison
`mix maya.compare_models` SHALL run the Roxanne Question through each given model (or 2 or 3 configured defaults) and print, per model, the agent-stage milliseconds and the Answer or the error.

#### Scenario: Compare two models
- **WHEN** `mix maya.compare_models model-a model-b` runs against stubbed OpenRouter replies
- **THEN** it prints one line per model with its name, milliseconds and Answer

### Requirement: Progress reported in a Question becomes an Event
The system prompt SHALL tell the model to call `log_event` when the Guest reports a badge, a catch, an evolution, a level or a move, to call it with `undo` when the Guest says "no" or "undo that" right after a logged Event, and to say the tool's confirm or refusal line. The prompt SHALL show the Guest's latest Progress row, and tools later in the same turn SHALL use the Progress the Event produced.

#### Scenario: "I just earned Roxanne's badge"
- **WHEN** the model answers that Question with a `log_event` call for Roxanne's badge and then text
- **THEN** the tool message holds the confirm "Stone Badge logged. Mudkip would approve.", the Guest's Next gym is Brawly, and the next turn's system prompt says "Next gym: Brawly (badge 2)"

#### Scenario: Same turn uses the new Progress
- **WHEN** the model logs Roxanne's badge and then calls `gym_counter` for Brawly in the same turn
- **THEN** `gym_counter` returns Brawly's team, not `past_horizon`

#### Scenario: "Undo that"
- **WHEN** the next Question is "No, undo that" and the model calls `log_event` with `undo`
- **THEN** the Guest is back to 0 badges and the next system prompt says "Next gym: Roxanne (badge 1)"

#### Scenario: Prompt asks for log_event
- **WHEN** the system prompt is built
- **THEN** it names `log_event` and "undo", and contains neither "beat" nor "defeat"

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
A committed probe set SHALL hold 20 Questions for Progress at 0 badges, each with the tool call it leads to, and one forbidden list: gym leaders, badges, cities, routes and places past Rustboro, and the probed Pokémon. It SHALL include gift and legendary Pokémon. It SHALL also hold one honesty case (#118): a model reply that claims an Event or a refusal with no tool call in that turn, and a check that flags such a reply.

#### Scenario: Every probe is past the horizon
- **WHEN** each probe's tool call runs through the agent with Progress at 0 badges and the model stubbed
- **THEN** its tool result is `past_horizon` with a hint

#### Scenario: No forbidden name reaches the model
- **WHEN** the 20 probes run through the agent with the model stubbed
- **THEN** no forbidden name, in any letter case, appears in a system or tool message sent to the model

#### Scenario: A claimed Event without a tool call is flagged
- **WHEN** the stubbed model replies "I refused Ralts because your team is full." with no tool call in that turn
- **THEN** the honesty check flags the reply as stating a tool result not returned in this turn

### Requirement: Roxanne then Ralts in one Conversation
With Progress at 0 badges and a Team of Mudkip, "How do I earn Roxanne's badge?" then "Where do I catch a Ralts?" in the same Conversation SHALL each get a Fact from a tool, and the second request SHALL carry the first turn.

#### Scenario: Sunday Questions with the model stubbed
- **WHEN** the two Questions are asked in order, the stubbed model calling `gym_counter` for Roxanne and then `find_pokemon` for Ralts
- **THEN** the first tool result names Nosepass as Roxanne's ace and Mudkip as the suggested lead
- **AND** the second tool result lists Route 102
- **AND** the second request has the first Question and Answer before the second Question

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
