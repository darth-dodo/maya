## MODIFIED Requirements

### Requirement: Progress reported in a Question becomes an Event
The system prompt SHALL tell the model to call `log_event` when the Guest reports a badge, a catch, an evolution, a level or a move, to call it with `undo` when the Guest says "no" or "undo that" right after a logged Event, to call it with `released` when the Guest released a Pokémon or has one on the Team twice, and to say the tool's confirm or refusal line. It SHALL also carry one line each for `deposited` (a Pokémon put in the PC), `withdrawn` (one taken out of the PC), `set_lead` (a new lead), `set_team` (the Guest says their whole Team, in one call, never one call per member) and `set_level` (any level, up or down), and SHALL say never to claim a Team change unless `log_event` confirmed it. The prompt SHALL show the Guest's latest Progress row, and tools later in the same turn SHALL use the Progress the Event produced.

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

#### Scenario: "My Team is Mudkip 16, Taillow 12"
- **WHEN** the stubbed model answers that Question with one `log_event` call of kind `set_team`
- **THEN** the tool message holds the confirm, and the next turn's system prompt says "Team: mudkip level 16, taillow level 12"

#### Scenario: Gym counter after a new lead
- **WHEN** the stubbed model logs `set_lead` Wingull and then calls `gym_counter` for Roxanne in the same turn
- **THEN** the `gym_counter` result lists the player's Team with Wingull first

## ADDED Requirements

### Requirement: Team change probe cases
The spoiler probe set SHALL gain Team change cases for Progress at 0 badges and a Team of Mudkip, each with its tool call: "My Team is Mudkip 16 and Poochyena 9" (`set_team`), "I put Poochyena in the PC" (`deposited`) and "Poochyena is level 9" (`set_level`). Their confirms SHALL name only species the Question named, and the honesty set (#118) SHALL hold a stubbed reply that claims a Team change with no tool call.

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
