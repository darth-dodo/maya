## Purpose

Defines what a change must pass before it can merge to main, and what is verified after main deploys, so broken releases are caught on the PR and failed deploys never go unnoticed.

## ADDED Requirements

### Requirement: Single required merge check
A pull request to main SHALL be mergeable only when the aggregate check `ci-success` passes, and `ci-success` SHALL pass only when every pipeline job (format, credo, test, docker, security) succeeded.

#### Scenario: One job fails
- **WHEN** any pipeline job fails or is cancelled on a pull request
- **THEN** `ci-success` fails
- **AND** the pull request cannot be merged

#### Scenario: All jobs pass
- **WHEN** every pipeline job succeeds on a pull request
- **THEN** `ci-success` passes

### Requirement: Release image proven on every pull request
Every pull request SHALL build the production release image and start it, and SHALL fail when the image does not build or the started service does not answer its liveness check.

#### Scenario: Release cannot start
- **WHEN** a pull request makes the release fail at boot (for example a runtime configuration error)
- **THEN** the docker job fails before merge

#### Scenario: Release starts
- **WHEN** the image builds and is started with test configuration and no reachable database
- **THEN** its liveness endpoint answers HTTP 200 within 60 seconds

### Requirement: Security scans on every pull request
Every pull request SHALL fail when a dependency has a known vulnerability advisory or the code has a high-confidence web security finding.

#### Scenario: Vulnerable dependency
- **WHEN** the lock file contains a dependency version with a published advisory
- **THEN** the security job fails and names the dependency

#### Scenario: High-confidence finding
- **WHEN** the code contains a high-confidence web security finding
- **THEN** the security job fails and names the file

### Requirement: Post-deploy smoke check
After every push to main, the pipeline SHALL wait until the live service reports that commit as its version, then verify the home page and liveness endpoint, and SHALL open an Issue labelled `bug` when either the deploy does not go live within 20 minutes or a check fails.

#### Scenario: Deploy goes live
- **WHEN** the live version endpoint reports the pushed commit within 20 minutes
- **AND** the home page and liveness endpoint answer HTTP 200
- **THEN** the smoke check passes and no Issue is opened

#### Scenario: Deploy never goes live
- **WHEN** the live version endpoint does not report the pushed commit within 20 minutes
- **THEN** an Issue labelled `bug` is opened naming the commit and linking the workflow run

#### Scenario: Live checks fail
- **WHEN** the pushed commit is live but the home page or liveness endpoint does not answer HTTP 200
- **THEN** an Issue labelled `bug` is opened naming the failing URL and status
