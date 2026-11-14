## Purpose

Lets the hosting platform and the pipeline ask the running service whether it is alive and which commit it is running, without touching the database or a user session.

## ADDED Requirements

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
