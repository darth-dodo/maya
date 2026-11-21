# llm-tracing Specification

## Purpose
A numbers-only Langfuse trace per Question (turn, round and tool spans) so agent latency, rounds, cache hits and tool misuse are visible without any Guest text leaving the app (ADR-010).

## Requirements

### Requirement: One trace per Question
When both Langfuse keys are set, each Question SHALL produce one trace with a turn span, one child span per round (completion request) and one child span per tool call. Each span's duration SHALL be its latency.

#### Scenario: Two rounds with one tool call
- **WHEN** a Question is answered in 2 rounds and the first round calls `find_pokemon`
- **THEN** the exported trace has one turn span, 2 round spans and 1 tool span under the first round, each with a start and end time

### Requirement: Span numbers
The turn span SHALL carry the model id, rounds, prompt, cached and completion tokens summed over rounds, the honesty check outcome (`ok` or a reason atom) and, on failure, the error reason atom. Each round span SHALL carry its own token counts. Each tool span SHALL carry the tool name (`unknown` for a name the model made up) and one status: `ok`, `not_found`, `past_horizon`, `refused` or `error`.

#### Scenario: Turn numbers match the turn log line
- **WHEN** a Question is answered with stubbed `usage` of 900 prompt, 600 cached and 40 completion tokens over 2 rounds
- **THEN** the turn span has rounds 2, those token sums, the model id and honesty `ok`, matching the turn log line

#### Scenario: Tool status
- **WHEN** a tool call returns `{:error, :past_horizon}`
- **THEN** its span has the tool name and status `past_horizon`

#### Scenario: Failed turn
- **WHEN** the agent runs out of time
- **THEN** the turn span has reason `timeout`

### Requirement: Numbers and tool names only
No span attribute SHALL hold the Question, the Answer, the system prompt, history, tool arguments or results, Progress, the guest id or a key. Attribute values SHALL be integers, atoms, tool names or the model id.

#### Scenario: No Question or Answer text
- **WHEN** a Question with known text is answered with a known Answer
- **THEN** no attribute of any exported span contains the Question text or the Answer text

#### Scenario: No guest id or tool arguments
- **WHEN** a turn for a known guest id calls a tool with known arguments
- **THEN** no attribute contains the guest id or any argument value

### Requirement: Off when unset
When `LANGFUSE_PUBLIC_KEY` or `LANGFUSE_SECRET_KEY` is unset, as in dev, test and CI, Maya SHALL export no spans and SHALL answer as before.

#### Scenario: Keys unset
- **WHEN** the app runs with neither key set and a Question is answered
- **THEN** no request is made to Langfuse and the Answer is the same as without tracing

### Requirement: Export never on the turn path
Export SHALL be async in its own process. A slow, refused or failing export SHALL NOT delay, change or crash a turn.

#### Scenario: Langfuse unreachable
- **WHEN** the exporter points at a refused port and a Question is answered
- **THEN** the Guest gets the normal Answer and the Conversation keeps running

### Requirement: No added agent latency
The build SHALL measure agent-stage p50 and p95 with `mix maya.latency` (or 10 Questions on the phone) before and after, and the after numbers SHALL show no added latency within run to run noise.

#### Scenario: Before and after
- **WHEN** the build PR is opened
- **THEN** its body has agent p50 and p95 from before and after tracing, and Answer time p95 is at most 8 s
