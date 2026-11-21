# agent Specification

## Purpose
How Maya turns a Question into an Answer: a tool-calling loop over OpenRouter, tools that return Facts from Maya's own data inside the Spoiler horizon (ADR-004), and the rules every Answer follows.

## Requirements

### Requirement: Tool-calling agent loop
Maya SHALL answer a Question with a hand-written loop over OpenRouter chat completions, the model name from config. Every request SHALL include the tool definitions, the Answer `response_format` and `provider.require_parameters` true. Maya SHALL parse each `tool_calls` entry's `arguments` JSON on its own, run the tool, and send one `role: "tool"` message per call with its `tool_call_id`. The loop SHALL end on an Answer that passes the honesty check, or the fallback line, within 4 requests.

#### Scenario: Roxanne round trip
- **WHEN** Progress has 0 badges and a Team of Mudkip at level 5, the Question is "How do I earn Roxanne's badge?", and the model first calls `gym_counter` with `{"leader": "Roxanne"}` and then replies `{"answer": "Lead with Mudkip against Nosepass.", "used_tool_calls": ["<that call's id>"]}`
- **THEN** the second request carries one tool message with the call's `tool_call_id` whose content names Roxanne's ace Nosepass at level 15 and suggests Mudkip as the lead
- **AND** both requests include the tool definitions, the configured model, the `answer` JSON schema and `require_parameters` true
- **AND** the Answer is "Lead with Mudkip against Nosepass."

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
Maya SHALL send the last 25 turns of the Conversation (50 messages) as context between the system prompt and the Question. The Conversation SHALL keep and, after a restart, reload its last 25 stored turns, and the Talk screen SHALL show those 25 (decided by Abhishek on 2026-11-21).

#### Scenario: Last 5 turns as context
- **WHEN** the Conversation has 5 stored turns and a new Question arrives
- **THEN** the request has the system prompt, all 5 turns as user and assistant messages in order, then the Question

#### Scenario: Last 25 turns as context
- **WHEN** the Conversation has 30 stored turns and a new Question arrives
- **THEN** the request has the system prompt, the last 25 turns as user and assistant messages in order, then the Question

#### Scenario: Reload after a restart
- **WHEN** a Guest has 30 stored turns and their Conversation process starts again
- **THEN** the next agent request carries the last 25 of them
- **AND** the Talk screen shows those 25 turns, and after the next Answer the oldest drops so it still shows 25

### Requirement: Model comparison
`mix maya.compare_models` SHALL run the Roxanne Question through each given model (or 2 or 3 configured defaults) and print, per model, the agent-stage milliseconds and the Answer or the error.

#### Scenario: Compare two models
- **WHEN** `mix maya.compare_models model-a model-b` runs against stubbed OpenRouter replies
- **THEN** it prints one line per model with its name, milliseconds and Answer

### Requirement: Progress reported in a Question becomes an Event
The system prompt SHALL tell the model to call `log_event` when the Guest reports a badge, a catch, an evolution, a level or a move, to call it with `undo` when the Guest says "no" or "undo that" right after a logged Event, to call it with `released` when the Guest released a Pokémon or has one on the Team twice, and to say the tool's confirm or refusal line. The prompt SHALL show the Guest's latest Progress row, and tools later in the same turn SHALL use the Progress the Event produced.

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
- **THEN** it names `log_event`, "undo", `deposited`, `withdrawn`, `set_lead`, `set_team` and `set_level`, and contains neither "beat" nor "defeat"

### Requirement: Team changes by voice in the prompt
The system prompt SHALL carry one line each for `deposited` (a Pokémon put in the PC), `withdrawn` (one taken out of the PC), `set_lead` (a new lead), `set_team` (only when the Guest lists every member, in one call; members left out go to the PC) and `set_level` (one member with a level, any level up or down), and SHALL say never to claim a Team change unless `log_event` confirmed it.

#### Scenario: "My Team is Mudkip 16, Taillow 12"
- **WHEN** the stubbed model answers that Question with one `log_event` call of kind `set_team`
- **THEN** the tool message holds the confirm, and the next turn's system prompt says "Team: mudkip level 16, taillow level 12"

#### Scenario: "Lotad level 14." is one member
- **WHEN** the system prompt and the `log_event` description are built
- **THEN** both say `set_team` is only for the whole Team and one member with a level is `set_level`

#### Scenario: Gym counter after a new lead
- **WHEN** the stubbed model logs `set_lead` Wingull and then calls `gym_counter` for Roxanne in the same turn
- **THEN** the `gym_counter` result lists the player's Team with Wingull first

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
The system prompt SHALL tell the model to call `move_learnset` before naming a move a Pokémon learns, and never to name a move no tool returned in this turn (`gym_counter` also returns a leader's moves).

#### Scenario: Prompt names the move tool
- **WHEN** the system prompt is built for any Progress
- **THEN** it contains `move_learnset` and the rule never to name a move no tool returned
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

### Requirement: Team change probe cases
The spoiler probe set SHALL gain Team change cases for Progress at 0 badges and a Team of Mudkip, each with its tool call: "My Team is Mudkip 16 and Poochyena 9" (`set_team`), "I put Poochyena in the PC" (`deposited`) and "Poochyena is level 9" and "Lotad level 14." (`set_level`). Their confirms SHALL name only species the Question named, and the honesty set (#118) SHALL hold a stubbed reply that claims a Team change with no tool call.

#### Scenario: Team probes pass the spoiler gate
- **WHEN** the Team change cases run through the agent with the model stubbed
- **THEN** no forbidden name appears in any system or tool message sent to the model

#### Scenario: A claimed Team change without a tool call is flagged
- **WHEN** the stubbed model replies "Done, Wingull leads your Team now." with no tool call in that turn
- **THEN** the honesty check flags the reply

### Requirement: Team tool latency
Adding the Team kinds to the `log_event` schema SHALL keep Answer time p95 at most 8 s, and the build PR SHALL show agent-stage p50 and p95 from `mix maya.latency` before and after.

#### Scenario: Latency before and after
- **WHEN** 10 Questions run on the phone before and after the change
- **THEN** the PR lists agent-stage p50 and p95 for both runs
- **AND** Answer time p95 after the change is at most 8 s

### Requirement: Structured Answer
The model's final reply SHALL be a JSON object with a non-empty string `answer` and an array `used_tool_calls` of tool call ids, and nothing else. Maya SHALL validate it with an embedded schema; only `answer` SHALL be spoken, shown and stored as the turn's Answer.

#### Scenario: Valid Answer
- **WHEN** the model replies `{"answer": "Not sure, that one is not in my notes.", "used_tool_calls": []}`
- **THEN** the Answer is "Not sure, that one is not in my notes."

#### Scenario: Reply that is not the schema
- **WHEN** the model replies with plain text, with JSON missing `answer`, or with an empty `answer`
- **THEN** the reply is rejected and handled as a rejected Answer

### Requirement: Honesty check with one corrective request
Maya SHALL ignore cited ids that did not run this turn, and reject an Answer that talks about tools when the Question does not, or claims a write (an Event logged or refused, a Team or Dial changed) when no `log_event` or `set_setting` confirmed this turn. A rejected Answer SHALL never be spoken. Maya SHALL send one corrective request at most. When the turn would end in the fallback line or an error, the Answer SHALL be the confirm or refused line of a write that ran, else the fallback line.

#### Scenario: Claimed refusal without a tool call
- **WHEN** the Question is "Can you add Ralts to my team?" and the stubbed model replies `{"answer": "I refused Ralts because your team is full.", "used_tool_calls": []}` with no tool call in this turn
- **THEN** Maya sends one corrective request naming the reason
- **AND** if the corrected reply passes, it is the Answer; if it fails again, the Answer is "Not sure I got that right, ask me again?"

#### Scenario: Cited tool call that did not happen
- **WHEN** the model replies with `used_tool_calls` `["call_9"]` and no tool call `call_9` happened in this turn
- **THEN** `call_9` is ignored and no corrective request is sent
- **AND** if the Answer claims a write and no write ran, it is still rejected as an unbacked claim

#### Scenario: Confirm backed by log_event
- **WHEN** the model calls `log_event` for a caught Ralts, the tool result is a confirm, and the model replies with an Answer saying Ralts was added and citing that call's id
- **THEN** the Answer passes without a corrective request

#### Scenario: Team set, nothing cited
- **WHEN** `log_event` `set_team` ran, `used_tool_calls` is `[]` and the Answer is "Team set: Mudkip level 16, Taillow level 12."
- **THEN** the Answer passes without a corrective request

#### Scenario: Ordinary words with no write
- **WHEN** no write ran and the Answer is "Got it, Brawly uses Fighting types." or "Noted, Brawly is tough."
- **THEN** the Answer passes: "updated", "changed", "noted", "saved" and "recorded" are a claim only in a sentence with a Progress noun (team, badge, badges, PC, box, location)

#### Scenario: A write is never silent
- **WHEN** `log_event` ran and then both replies are rejected, the round cap is hit or OpenRouter fails
- **THEN** the Answer is that call's confirm line, or its refused line

#### Scenario: The Guest asks about tools
- **WHEN** the Question is "What tools do you have?" and the Answer names tools
- **THEN** the Answer passes

#### Scenario: Only one corrective request
- **WHEN** the model's first and corrected replies are both rejected and no write ran
- **THEN** Maya makes no third attempt and the Answer is the fallback line

#### Scenario: Slateport claimed, then tool talk
- **WHEN** the Question is "I'm in Slateport", the model replies that Slateport is logged with no tool call, and the corrected reply says it never called the tool
- **THEN** neither reply is spoken: talk about tools the Question did not ask about is rejected like an unbacked claim
- **AND** the Answer is "Not sure I got that right, ask me again?"

### Requirement: Only a confirmed write backs a claim
A write claim SHALL be backed only by a `log_event` or `set_setting` whose tool result this turn was a confirm, read from the tool result and never from the Answer text. A refused or failed write SHALL back no claim, though its refused line may be said. When the turn would end in the fallback line, the refused line SHALL be said (#192).

#### Scenario: Refused set_setting, claimed change
- **WHEN** `set_setting` humor 150 is refused and the model replies "Humor set to 100." twice
- **THEN** both replies are rejected and the Answer is "Humor goes from 0 to 100 percent, so it stays as it is."

#### Scenario: Confirmed set_setting
- **WHEN** `set_setting` humor 100 returns a confirm and the model replies "Humor set to 100."
- **THEN** the Answer passes with no corrective request

#### Scenario: Refused line said as is
- **WHEN** `log_event` is refused with "Every badge is already logged." and the Answer says that line
- **THEN** the Answer passes

### Requirement: A tool is called, never promised
The system prompt SHALL tell the model to call a tool in the same turn, before it replies, and never to announce a tool action. Maya SHALL reject an Answer whose sentence, not a question, promises a tool action ("Running the team check now.", "I'll run it now", "Let me check") when the named tool did not run this turn, or no tool is named and none ran. It SHALL send one corrective request naming the tool, then the fallback line (#222).

#### Scenario: Prompt carries the call rule
- **WHEN** the system prompt is built for any Progress
- **THEN** it tells the model to call the tool in this same turn and never to announce a tool action

#### Scenario: Wattson team check promised at 2 badges
- **WHEN** the last turn offered a team check, the Question is "Yes" and the stubbed model replies "Running the team check for Wattson's gym now." with no tool call
- **THEN** Maya sends one corrective request saying "Call team_check now"
- **AND** the model calls `team_check` and its Answer with the result is said

#### Scenario: Promised again after the correction
- **WHEN** both replies promise the team check and no tool ran
- **THEN** the Answer is "Not sure I got that right, ask me again?" with no third request

#### Scenario: An offer is not a promise
- **WHEN** no tool ran and the Answer is "Want me to run a team check for Wattson?", "Looking good, Mudkip would approve." or "Let me know when you reach Mauville."
- **THEN** the Answer passes with no corrective request

#### Scenario: The named tool ran
- **WHEN** `team_check` ran and the Answer is "Let me check the team check: you're ready."
- **THEN** the Answer passes

#### Scenario: Probe case
- **WHEN** each `tool_promises` reply in the probe set runs through the agent with the model stubbed
- **THEN** it ends corrected or replaced, never said

### Requirement: Tool calls during a database outage
When Postgres cannot be reached during a tool call (`find_pokemon`, `gym_counter`, `move_learnset`, `search_guide`, `find_trainer`, `find_item`, `team_check`, `log_event`, `set_setting`), the tool SHALL return the error `notes_down` and never crash. The agent SHALL then end the turn with "I can't reach my notes right now, ask again soon?", after any confirm line, with no further request. The log SHALL name only the tool and the error kind.

#### Scenario: A read during an outage
- **WHEN** the model calls `find_pokemon` for "Ralts" and the database read fails
- **THEN** the tool message is `{"error": "notes_down"}`, the Answer is "I can't reach my notes right now, ask again soon?" and no second request is sent
- **AND** the log says `tool find_pokemon failed` with the error kind

#### Scenario: Every tool during an outage
- **WHEN** any tool above is called while the database is down
- **THEN** its tool message is `{"error": "notes_down"}` and Progress is unchanged

### Requirement: Honesty rule in the system prompt
The system prompt SHALL tell the model to reply in the Answer schema, to list in `used_tool_calls` the id of every tool call whose result the Answer uses, never to claim a tool call, its result or a refusal unless it happened in this turn, and to say plainly when unsure. It SHALL tell the model never to mention tools, calling or its own steps to the Guest, and to state a correction plainly ("You're in Petalburg City, got it.").

#### Scenario: Prompt carries the honesty rule
- **WHEN** the system prompt is built for any Progress
- **THEN** it contains `used_tool_calls` and the rule never to claim a tool result not returned in this turn
- **AND** it contains the rule never to mention tools and to state a correction plainly
- **AND** it contains neither "beat" nor "defeat"

### Requirement: Spoken Answer length
Maya SHALL speak at most 3 sentences of an Answer. A longer `answer` SHALL be trimmed to its first 3 sentences, without another request, and the honesty check SHALL run on the trimmed text.

#### Scenario: Five sentences
- **WHEN** the model's `answer` has five sentences
- **THEN** the Answer is its first three sentences and no further request is sent
- **AND** an abbreviation such as "Mt. Pyre" does not end a sentence

### Requirement: Structured Answer latency
The structured Answer SHALL keep Answer time p95 at most 8 s. The build PR SHALL show agent-stage p50 and p95 from `mix maya.latency` before and after, and how many of the measured Questions needed the corrective request.

#### Scenario: Latency before and after
- **WHEN** 10 Questions run on the phone before and after the change
- **THEN** the PR lists agent-stage p50 and p95 for both runs and the corrective request count
- **AND** Answer time p95 after the change is at most 8 s

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

### Requirement: Trainers on a place
The agent SHALL offer a `find_trainer` tool with one required string argument `place`. It SHALL return `{:ok, fact}` with the place and each trainer's name and first party (species and levels) when the place is listed and inside the Spoiler horizon, and `{:error, :past_horizon}` when the place is past the horizon or not listed. A rematch party SHALL never be returned.

#### Scenario: Route 102 at 0 badges
- **WHEN** Progress has 0 badges and `find_trainer` is called for "Route 102"
- **THEN** the Fact lists Calvin with Poochyena at level 5
- **AND** it does not list Mightyena or any level above 15

#### Scenario: Place past the horizon
- **WHEN** Progress has 0 badges and `find_trainer` is called for "Route 110" or "Dewford Town"
- **THEN** it returns `past_horizon` with a hint naming no place

#### Scenario: Route 110 waits for badge 2
- **WHEN** Progress has badge 1 and `find_trainer` is called for "Route 110"
- **THEN** it returns `past_horizon` with a hint naming no place
- **AND** with badges 1 and 2 the Fact lists Route 110's trainers with their first parties

### Requirement: Where to get an item
The agent SHALL offer a `find_item` tool with one required string argument `name`. It SHALL return `{:ok, fact}` with each place inside the Spoiler horizon where the item is found, hidden, sold or given (place and how); `{:error, :past_horizon}` for a known item with no such place; and `{:error, :not_found}` for a name that is not an item in Maya's data. A gift SHALL be returned only from `gifts.json` and only when its `badges_required` is at most the badges earned.

#### Scenario: An item inside the horizon
- **WHEN** Progress has 0 badges and `find_item` is called for an item whose only row is a ball on Route 102
- **THEN** the Fact lists Route 102 with how `ball`

#### Scenario: Surf before badge 5
- **WHEN** Progress has 0 or 2 badges and `find_item` is called for "HM03"
- **THEN** it returns `past_horizon` and no place, including no Petalburg City

#### Scenario: Mach Bike waits for badge 2
- **WHEN** Progress has badge 1 and `find_item` is called for "Mach Bike"
- **THEN** it returns `past_horizon` and no place
- **AND** with badges 1 and 2 the Fact names Mauville City with how `gift`

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

#### Scenario: Wattson is the Next gym
- **WHEN** Progress has badges 1 and 2 and a Team of Marshtomp
- **THEN** the Fact names Wattson and his ace from Maya's trainer data
- **AND** it names neither Flannery nor any later leader

#### Scenario: Empty Team
- **WHEN** Progress has 0 badges and an empty Team
- **THEN** the Fact has no Team members and `ready` false

### Requirement: The rival's party by starter
`find_trainer` SHALL return the rival once, with only the party for the player's starter: the one starter line (Treecko, Torchic or Mudkip, or an evolution) in the Team or PC box. May and Brendan SHALL be one entry when their parties match. With no starter line or more than one, it SHALL return one line saying the rival's team depends on the starter, and no rival party.

#### Scenario: Mudkip on the Team
- **WHEN** Progress has 0 badges and a Team of Mudkip, and `find_trainer` is called for "Route 103"
- **THEN** the Fact has one rival entry, "May or Brendan", with Treecko at level 5
- **AND** it names no Torchic and no other trainer

#### Scenario: Starter unknown
- **WHEN** neither the Team nor the PC box holds a starter line
- **THEN** the rival entry is one line saying the team depends on the starter, with no party

### Requirement: Trainer, item and readiness rules in the system prompt
The system prompt SHALL tell the model to call `find_trainer` for trainers on a place, `find_item` for where to get an item, and `team_check` when the player asks whether the Team is ready, and to state only what those tools return.

#### Scenario: Prompt names the three tools
- **WHEN** the system prompt is built for any Progress
- **THEN** it contains `find_trainer`, `find_item` and `team_check`
- **AND** it contains neither "beat" nor "defeat"

### Requirement: Trainer, item and readiness probe cases
The spoiler probe set SHALL gain trainer, item and readiness cases beyond the 20 Sunday goal Questions, at 0, 1 and 2 badges, each case with the forbidden names for its badge count.

#### Scenario: Probes at 0 badges
- **WHEN** Progress has 0 badges and a Team of Mudkip, and "Who battles me on Route 110?", "Where do I get Surf?", "Where is the Mach Bike?", "Who is on Route 102?" and "Is my Team ready?" run with the model stubbed
- **THEN** the first three return `past_horizon`, the fourth a Fact with no rematch party, the fifth a `team_check` Fact naming no leader but Roxanne
- **AND** no forbidden name appears in any message sent to the model

#### Scenario: Nothing about Mauville at 1 badge
- **WHEN** Progress has badge 1, and "Who battles me on Route 110?" and "Where is the Mach Bike?" run
- **THEN** both return `past_horizon`
- **AND** no message sent to the model names Mauville, Route 107, 108, 110 or Wattson

#### Scenario: Only Wattson at 2 badges
- **WHEN** Progress has badges 1 and 2, and "Is my Team ready?" runs
- **THEN** the `team_check` Fact names no leader but Wattson
- **AND** no message sent to the model names Flannery or Lavaridge

### Requirement: Trainer and item tool latency
Adding the three tools SHALL keep Answer time p95 at most 8 s, and each build PR SHALL show agent-stage p50 and p95 from `mix maya.latency` before and after.

#### Scenario: Latency before and after
- **WHEN** 10 Questions run on the phone before and after the change
- **THEN** the PR lists agent-stage p50 and p95 for both runs
- **AND** Answer time p95 after the change is at most 8 s

### Requirement: Prompt caching through OpenRouter
For a model id starting with `anthropic/`, every agent request SHALL carry top-level `cache_control` `{"type": "ephemeral"}`; other models SHALL get no `cache_control`. Tools, system prompt and history SHALL keep their order, so while Progress is unchanged each request starts with the same messages as the one before it.

#### Scenario: Anthropic model
- **WHEN** the configured model is `anthropic/claude-haiku-5.5` and a Question is answered in 2 rounds, the first calling a read tool
- **THEN** both request bodies have `cache_control` `{"type": "ephemeral"}`
- **AND** the second request's messages start with every message of the first

#### Scenario: Other model
- **WHEN** the model is `google/gemini-3.8-flash`
- **THEN** the request body has no `cache_control`

#### Scenario: Next turn reuses the front
- **WHEN** two Questions follow each other with no Progress change
- **THEN** the second turn's first request starts with the system prompt and every history message of the first turn's request

### Requirement: Turn log line
After each Question its loop ends (an Answer, the fallback line or an error) the agent SHALL log one info line with the rounds used, the history turns sent, and the prompt and cached tokens summed from the replies' `usage` (0 when absent). The line SHALL NOT contain the Question, the Answer or any tool content.

#### Scenario: Two rounds with a cache hit
- **WHEN** a Question takes 2 rounds with 25 history turns and the replies report 3000 prompt tokens, 2400 of them cached
- **THEN** one info line says rounds 2, history 25, prompt tokens 3000, cached 2400
- **AND** it contains neither the Question nor the Answer

### Requirement: Longer memory latency
Sending 25 turns SHALL keep Answer time p95 at most 8 s. The build PR SHALL show agent-stage p50 and p95 from `mix maya.latency` (or Abhishek's phone run) before and after, and one live turn log line with cached tokens above 0.

#### Scenario: Latency before and after
- **WHEN** 10 Questions run on the phone in one Conversation before and after the change
- **THEN** the PR lists agent-stage p50 and p95 for both runs and a turn log line with cached tokens above 0
- **AND** Answer time p95 after the change is at most 8 s

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
