## ADDED Requirements

### Requirement: Errors reach Sentry
When `SENTRY_DSN` is set, Maya SHALL send an event to Sentry for each crash in the Conversation, the Agent or a turn Task, each LiveView or controller error, and each logger message at error level. Each event SHALL carry `release` set to `RENDER_GIT_COMMIT` and an `environment`. Warnings SHALL be breadcrumbs, never their own events.

#### Scenario: Turn Task crash
- **WHEN** `SENTRY_DSN` is set and the agent Task for a Question raises
- **THEN** one event reaches the Sentry test sender with the exception type, the stack trace, the release and the tag `stage: agent`

#### Scenario: Warning is a breadcrumb
- **WHEN** a `Logger.warning` line is logged and then an error occurs
- **THEN** only the error is an event, and the warning is one of its breadcrumbs

### Requirement: Metadata only
Before sending, a `before_send` SHALL strip request bodies, LiveView event params, cookies, headers, user data, extra data and any string longer than a short limit. Tags SHALL be only the stage (`stt`, `agent`, `tts`, `import`) and reason atoms. No event SHALL hold audio, a Question, an Answer, Progress, a guest id or a key.

#### Scenario: Turn crash holds no content
- **WHEN** a turn crashes while its state holds a Question, an Answer and a guest id
- **THEN** the event sent has none of the Question, the Answer or the guest id in any field

#### Scenario: Controller error holds no request data
- **WHEN** a controller raises on a request with a cookie and a body
- **THEN** the event sent has no cookie, header or body

### Requirement: Off when unset
When `SENTRY_DSN` is unset, as in dev, test and CI, Maya SHALL send no events and SHALL start and answer as before. No browser SDK SHALL be added, so the CSP stays unchanged.

#### Scenario: No DSN
- **WHEN** the app runs with `SENTRY_DSN` unset and a turn crashes
- **THEN** no request is made to Sentry and the Guest hears the usual error line

#### Scenario: CSP unchanged
- **WHEN** the Talk page is loaded
- **THEN** its `content-security-policy` header is the same as before this change

### Requirement: Live check after deploy
After the deploy that ships this change, one deliberate test error SHALL show up in Sentry with the deployed commit as its release.

#### Scenario: Test error in production
- **WHEN** Abhishek has set `SENTRY_DSN` on Render and the test error is triggered
- **THEN** it appears in Sentry with `release` equal to the live `RENDER_GIT_COMMIT`
