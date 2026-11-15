## ADDED Requirements

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
