## MODIFIED Requirements

### Requirement: Single required merge check
A pull request to main SHALL be mergeable only when the aggregate check `ci-success` passes, and `ci-success` SHALL pass only when every pipeline job (format, credo, test, spoiler-gate, docker, security) succeeded.

#### Scenario: One job fails
- **WHEN** any pipeline job fails or is cancelled on a pull request
- **THEN** `ci-success` fails
- **AND** the pull request cannot be merged

#### Scenario: All jobs pass
- **WHEN** every pipeline job succeeds on a pull request
- **THEN** `ci-success` passes

## ADDED Requirements

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
