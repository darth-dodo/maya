## MODIFIED Requirements

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

## ADDED Requirements

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
After each answered Question the agent SHALL log one info line with the rounds used, the history turns sent, and the prompt and cached tokens summed from the replies' `usage` (0 when absent). The line SHALL NOT contain the Question, the Answer or any tool content.

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
