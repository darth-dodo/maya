# Spec Delta

## ADDED Requirements

### Requirement: STT is biased toward known names
Every STT request SHALL carry the documented `context_bias` field, one form field per term. The terms SHALL come from Maya's game data and the Guest's Progress: "Maya", "Mudkip", the Team, the Next gym leader, locations inside the Spoiler horizon, then every other known species, gym leader, gym city and location. Terms SHALL be unique and SHALL be capped at 400.

#### Scenario: Bias terms in the request
- **WHEN** a Guest with Mudkip on the Team and no badges asks a Question
- **THEN** the STT request has one `context_bias` field each for "Maya", "Mudkip", "Roxanne", "Rustboro City", "Ralts" and "Torchic"
- **AND** no term repeats, there are at most 400 terms and their total size is under 8 KB

#### Scenario: Priority order when capped
- **WHEN** the terms are capped below the full list
- **THEN** "Maya", "Mudkip", the Team, the Next gym leader and the horizon locations come first and the rest is cut from the end

### Requirement: Bias terms only steer recognition
Bias terms SHALL NOT be shown to the player and SHALL NOT be sent to the agent's model as Facts; only the player's own transcript reaches the agent.

#### Scenario: No past-horizon name reaches the model from the bias
- **WHEN** a Guest with no badges asks "hello"
- **THEN** the agent's request contains no bias term the player did not say, such as "Sootopolis City"

### Requirement: Transcript names are corrected before the agent
The transcript SHALL be corrected before the agent sees it: a word, or two adjacent words joined, that is close to a known name by Jaro distance (at least 0.86, same first letter, not a prefix of the name, length within 2) SHALL become that name. A word on the committed list of English words near a name, or shorter than 4 letters, SHALL stay as spoken. A possessive and punctuation SHALL be kept. The shown and stored Question SHALL be the corrected text.

#### Scenario: Real misses are corrected
- **WHEN** the transcript is "where do I catch rawls", "what is torch ick weak to", "is zigzag goon on route 101" or "how do I earn roxane's badge?"
- **THEN** the Question becomes "where do I catch Ralts", "what is Torchic weak to", "is Zigzagoon on route 101" or "how do I earn Roxanne's badge?"

#### Scenario: English words are kept
- **WHEN** the transcript contains "rocks", "beach", "where", "badge", "route", "rails", "golden", "which", "electric" or "around"
- **THEN** each of those words is unchanged

#### Scenario: The corrected Question is stored
- **WHEN** STT returns "where do I catch rawls?"
- **THEN** the agent is asked "where do I catch Ralts?" and the stored turn has that Question

### Requirement: STT stage latency with bias
The Progress read SHALL move into the STT stage and be reused by the agent, so a turn still reads Progress once. `stt_ms` SHALL include building the terms and the correction.

#### Scenario: One Progress read per turn
- **WHEN** a turn completes
- **THEN** it stores non-negative `stt_ms`, `agent_ms` and `tts_first_byte_ms`
- **AND** the Guest's Progress was read once for the turn
