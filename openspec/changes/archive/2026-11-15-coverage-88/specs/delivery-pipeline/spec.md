## MODIFIED Requirements

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
