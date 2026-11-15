# delivery-pipeline Specification

## Purpose

Defines what a change must pass before it can merge to main, and what is verified after main deploys, so broken releases are caught on the PR and failed deploys never go unnoticed.

## Requirements

### Requirement: Single required merge check
A pull request to main SHALL be mergeable only when the aggregate check `ci-success` passes, and `ci-success` SHALL pass only when every pipeline job (format, credo, test, spoiler-gate, docker, security) succeeded.

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

### Requirement: Test coverage floor
Every pull request SHALL fail when total line coverage of application modules falls below the threshold recorded in the project, SHALL print coverage per module, and SHALL NOT lower that threshold. The test job SHALL also produce a line coverage report in a format Codecov accepts and upload it to Codecov, and an upload failure SHALL NOT fail the pipeline.

#### Scenario: Coverage drops below the floor
- **WHEN** a pull request makes total line coverage of application modules fall below the recorded threshold
- **THEN** the test job fails
- **AND** the log shows the total coverage and the threshold

#### Scenario: Coverage report visible
- **WHEN** the test job runs
- **THEN** its log shows a coverage table with one row per application module

#### Scenario: Coverage uploaded to Codecov
- **WHEN** the test job passes
- **THEN** an LCOV report with one record per application source file is uploaded to Codecov for that commit

#### Scenario: Codecov upload fails
- **WHEN** the Codecov token is missing or Codecov does not accept the upload
- **THEN** the test job still succeeds
- **AND** `ci-success` is decided by the other jobs only

### Requirement: Security scans on every pull request
Every pull request SHALL fail when a dependency has a known vulnerability advisory or the code has a high-confidence web security finding.

#### Scenario: Vulnerable dependency
- **WHEN** the lock file contains a dependency version with a published advisory
- **THEN** the security job fails and names the dependency

#### Scenario: High-confidence finding
- **WHEN** the code contains a high-confidence web security finding
- **THEN** the security job fails and names the file

### Requirement: Post-deploy smoke check
Every 15 minutes, and on manual dispatch, the pipeline SHALL compare the live version with the head of main; when they match it SHALL check `/`, `/talk` and the liveness endpoint. It SHALL open an Issue labelled `bug` when the head is not live 20 minutes after its commit or a check fails. It SHALL NOT be triggered by a push or wait for a deploy, and SHALL always succeed.

#### Scenario: Deploy goes live
- **WHEN** the live version endpoint reports the head commit of main
- **AND** the home page, the Talk screen and the liveness endpoint answer HTTP 200
- **THEN** the smoke check reports ok and no Issue is opened

#### Scenario: Deploy in progress
- **WHEN** the live version endpoint does not report the head commit of main
- **AND** that commit is less than 20 minutes old
- **THEN** the smoke check reports a deploy in progress and no Issue is opened

#### Scenario: Deploy never goes live
- **WHEN** the live version endpoint does not report the head commit of main
- **AND** that commit is more than 20 minutes old
- **THEN** an Issue labelled `bug` is opened naming the commit, the failure "not live after 20 minutes" and the workflow run

#### Scenario: Live checks fail
- **WHEN** the head commit of main is live but the home page, the Talk screen or the liveness endpoint does not answer HTTP 200
- **THEN** an Issue labelled `bug` is opened naming the commit, the failing URL and its status

#### Scenario: Issue already open for that commit
- **WHEN** a problem is found for a commit
- **AND** an open Issue whose title contains that commit's short SHA exists
- **THEN** no new Issue is opened

#### Scenario: Smoke check never blocks a deploy
- **WHEN** a commit is pushed to main
- **THEN** no smoke check run is triggered by that push
- **AND** every smoke check run finishes within 5 minutes and exits successfully, whatever it finds

### Requirement: Post-deploy Question
Once an hour, and on manual dispatch, the smoke check SHALL ask the live head commit one Question through the smoke Question endpoint when the smoke token is set, and SHALL open an Issue labelled `bug` (one per commit) when the response is not HTTP 200, the Answer is empty or the Answer is the agent error line. It SHALL always succeed, like the smoke check.

#### Scenario: Production Question fails
- **WHEN** the head commit of main is live and its home page and liveness endpoint answer HTTP 200
- **AND** the run is the hourly scheduled run or a manual dispatch, with the smoke token set
- **AND** the smoke Question endpoint answers a status other than HTTP 200, an empty Answer or the agent error line
- **THEN** an Issue labelled `bug` is opened naming the commit and the failure

#### Scenario: No smoke token
- **WHEN** the smoke token is not set in the pipeline
- **THEN** the Question is skipped and no Issue is opened for it

### Requirement: Spoiler gate job
Every pull request SHALL run the spoiler probe set through the agent in its own job, `spoiler-gate`, with the model stubbed and no network call outside the job, and a leak SHALL fail `ci-success`.

#### Scenario: A leak fails the build
- **WHEN** a change lets a probe's tool result be a Fact, or a forbidden name reach a message sent to the model
- **THEN** the `spoiler-gate` job fails
- **AND** `ci-success` fails

#### Scenario: No leak
- **WHEN** every probe is `past_horizon` and no forbidden name reaches the model
- **THEN** the `spoiler-gate` job passes

### Requirement: Scheduled spoiler probe
Nightly and on manual dispatch, never on push or pull request, the pipeline SHALL ask production the 20 probe Questions through the smoke Question endpoint and check each Answer. It SHALL open one Issue labelled `bug` per run with a leak, and SHALL always succeed.

#### Scenario: A real Answer leaks
- **WHEN** an Answer contains a forbidden name not in its own Question, or forbidden wording
- **THEN** one Issue labelled `bug` is opened for the run, listing each leaking Question and Answer
- **AND** the run succeeds

#### Scenario: No leak
- **WHEN** no Answer contains a forbidden name or forbidden wording
- **THEN** no Issue is opened and the run succeeds

#### Scenario: No smoke token
- **WHEN** the smoke token is not set in the pipeline
- **THEN** the probe is skipped, no Issue is opened and the run succeeds
