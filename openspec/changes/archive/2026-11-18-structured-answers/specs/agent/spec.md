## MODIFIED Requirements

### Requirement: Tool-calling agent loop
Maya SHALL answer a Question with a hand-written loop over OpenRouter chat completions. Every request SHALL include the tool definitions, the structured Answer `response_format` and `provider.require_parameters` true. When the model replies with `tool_calls`, Maya SHALL parse each call's `arguments` JSON string on its own, run the tool, and send back exactly one `role: "tool"` message per call carrying that call's `tool_call_id`. The loop SHALL stop when the model replies with a structured Answer that passes the honesty check, or with the fallback line, and SHALL make at most 4 requests per Question. The model name SHALL come from config.

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

## ADDED Requirements

### Requirement: Structured Answer
The model's final reply SHALL be a JSON object with a non-empty string `answer` and an array `used_tool_calls` of tool call ids, and nothing else. Maya SHALL validate it with an embedded schema; only `answer` SHALL be spoken, shown and stored as the turn's Answer.

#### Scenario: Valid Answer
- **WHEN** the model replies `{"answer": "Not sure, that one is not in my notes.", "used_tool_calls": []}`
- **THEN** the Answer is "Not sure, that one is not in my notes."

#### Scenario: Reply that is not the schema
- **WHEN** the model replies with plain text, with JSON missing `answer`, or with an empty `answer`
- **THEN** the reply is rejected and handled as a rejected Answer

### Requirement: Honesty check with one corrective request
Maya SHALL reject an Answer that cites a tool call id not run this turn, or that claims a write (an Event logged or refused, a Team or Dial changed) without citing a `log_event` or `set_setting` call of this turn. A rejected Answer SHALL never be spoken. Maya SHALL send one corrective request at most; after a second rejection, or with no request or agent time left, the Answer SHALL be "Not sure I got that right, ask me again?".

#### Scenario: Claimed refusal without a tool call
- **WHEN** the Question is "Can you add Ralts to my team?" and the stubbed model replies `{"answer": "I refused Ralts because your team is full.", "used_tool_calls": []}` with no tool call in this turn
- **THEN** Maya sends one corrective request naming the reason
- **AND** if the corrected reply passes, it is the Answer; if it fails again, the Answer is "Not sure I got that right, ask me again?"

#### Scenario: Cited tool call that did not happen
- **WHEN** the model replies with `used_tool_calls` `["call_9"]` and no tool call `call_9` happened in this turn
- **THEN** the Answer is rejected and the corrective request is sent

#### Scenario: Confirm backed by log_event
- **WHEN** the model calls `log_event` for a caught Ralts, the tool result is a confirm, and the model replies with an Answer saying Ralts was added and citing that call's id
- **THEN** the Answer passes without a corrective request

#### Scenario: Only one corrective request
- **WHEN** the model's first and corrected replies are both rejected
- **THEN** Maya makes no third attempt and the Answer is the fallback line

#### Scenario: Slateport claimed, then tool talk
- **WHEN** the Question is "I'm in Slateport", the model replies that Slateport is logged with no tool call, and the corrected reply says it never called the tool
- **THEN** neither reply is spoken: talk about tools is rejected like an unbacked claim
- **AND** the Answer is "Not sure I got that right, ask me again?"

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
