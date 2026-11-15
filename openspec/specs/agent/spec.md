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
