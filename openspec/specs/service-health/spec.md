# service-health Specification

## Purpose

Lets the hosting platform and the pipeline ask the running service whether it is alive and which commit it is running, without touching the database or a user session, and lets the post-deploy check ask one real Question against production data.

## Requirements

### Requirement: Liveness
`GET /health` SHALL answer HTTP 200 with the body `ok` without reading the database or starting a session.

#### Scenario: Database unreachable
- **WHEN** the database is paused or unreachable
- **AND** a client requests `/health`
- **THEN** the response is HTTP 200 with body `ok`
- **AND** no session cookie is set

### Requirement: Deployed version
`GET /health/version` SHALL answer HTTP 200 with the commit SHA the service was deployed from as plain text, or `unknown` when the platform did not provide one, without reading the database or starting a session.

#### Scenario: Commit known
- **WHEN** the service was deployed from commit `abc123`
- **AND** a client requests `/health/version`
- **THEN** the response is HTTP 200 with body `abc123`

#### Scenario: Commit unknown
- **WHEN** no deploy commit is available (for example in local development)
- **AND** a client requests `/health/version`
- **THEN** the response is HTTP 200 with body `unknown`

### Requirement: Smoke Question
`POST /health/ask` with a JSON `question` SHALL answer the agent's Answer as JSON `{"answer": ...}` when the `x-smoke-token` header matches the configured smoke token, using the deployed game data and Progress, with no history, no speech and no stored turn. It SHALL answer HTTP 404 when no smoke token is configured, HTTP 401 for a missing or wrong token without calling the agent, and HTTP 503 with `{"error": <reason>}` when the agent fails.

#### Scenario: Token matches
- **WHEN** a client posts a Question with the configured smoke token
- **THEN** the response is HTTP 200 with the Answer and no turn is stored

#### Scenario: Wrong token
- **WHEN** a client posts a Question with a wrong token
- **THEN** the response is HTTP 401 and the agent is not called

#### Scenario: Endpoint off
- **WHEN** no smoke token is configured
- **THEN** the response is HTTP 404

#### Scenario: No Progress in production
- **WHEN** the database has no Progress
- **AND** a client posts a Question with the configured smoke token
- **THEN** the response is HTTP 503 with error `no_progress`
