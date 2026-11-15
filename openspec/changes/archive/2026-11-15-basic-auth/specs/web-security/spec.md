## ADDED Requirements

### Requirement: Shared login on pages that spend API credit
The Talk screen and `POST /fresh` SHALL require the one shared login (HTTP Basic auth). A request without credentials, or with wrong ones, SHALL get 401 with a `www-authenticate` header and none of the page. The right credentials SHALL get the page as before. The LiveView socket needs no separate check: it is only reachable from a page rendered after the login, and carries that page's signed session.

#### Scenario: No credentials
- **WHEN** a visitor without credentials requests the Talk screen `/`
- **THEN** the response is 401
- **AND** it has a `www-authenticate` header for Basic auth

#### Scenario: Start fresh without credentials
- **WHEN** a visitor without credentials sends `POST /fresh`
- **THEN** the response is 401

#### Scenario: Wrong credentials
- **WHEN** a visitor sends a wrong username or password to `/`
- **THEN** the response is 401

#### Scenario: Right credentials
- **WHEN** a visitor sends the configured username and password to `/`
- **THEN** the response is 200 and the Talk screen renders
- **AND** its LiveView connects

### Requirement: Public routes stay open
Health checks, the smoke endpoint and static files SHALL answer without the login, so Render health checks, the post-deploy smoke check and the browser's assets keep working.

#### Scenario: Health and static files without credentials
- **WHEN** a visitor without credentials requests `/health`, `/health/version`, `/robots.txt`, `/manifest.webmanifest` or an image under `/images/`
- **THEN** each answers 200

### Requirement: Production refuses to boot without the login
The production release SHALL fail at boot when `BASIC_AUTH_USERNAME` or `BASIC_AUTH_PASSWORD` is missing or empty, so a deploy never goes live without the login.

#### Scenario: Missing password
- **WHEN** the release boots in production without `BASIC_AUTH_PASSWORD`
- **THEN** boot fails with a message naming the missing variable and printing no credential
