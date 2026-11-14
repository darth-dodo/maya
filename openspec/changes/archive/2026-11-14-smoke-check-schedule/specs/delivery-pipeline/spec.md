## MODIFIED Requirements

### Requirement: Post-deploy smoke check
Every 15 minutes, and on manual dispatch, the pipeline SHALL compare the version reported by the live service with the head commit of main; when they match it SHALL verify the home page and liveness endpoint, and it SHALL open an Issue labelled `bug` when the head commit is not live 20 minutes after it was committed or a check fails. The smoke check SHALL NOT be triggered by a push, SHALL NOT wait for a deploy, and SHALL always succeed, so it cannot block a deploy.

#### Scenario: Deploy goes live
- **WHEN** the live version endpoint reports the head commit of main
- **AND** the home page and liveness endpoint answer HTTP 200
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
- **WHEN** the head commit of main is live but the home page or liveness endpoint does not answer HTTP 200
- **THEN** an Issue labelled `bug` is opened naming the commit, the failing URL and its status

#### Scenario: Issue already open for that commit
- **WHEN** a problem is found for a commit
- **AND** an open Issue whose title contains that commit's short SHA exists
- **THEN** no new Issue is opened

#### Scenario: Smoke check never blocks a deploy
- **WHEN** a commit is pushed to main
- **THEN** no smoke check run is triggered by that push
- **AND** every smoke check run finishes within 5 minutes and exits successfully, whatever it finds
