# guest-sessions Specification

## Purpose
Each browser is a Guest with a random id in the signed session cookie, owning one Conversation and one Progress; Guests never see each other's turns or Progress, and Start fresh gives a browser a new Guest.

## Requirements

### Requirement: Guest id in the signed session
Every browser request through the browser pipeline SHALL carry a guest id in the signed session cookie. When the session has none, a new one SHALL be made from 16 cryptographically random bytes, url-safe Base64 encoded; when it has one, it SHALL be kept unchanged. The Talk screen SHALL read the guest id from the session on mount.

#### Scenario: New visitor gets a guest id
- **WHEN** a visitor with no session opens `/`
- **THEN** the session holds a 22 character url-safe guest id

#### Scenario: Returning visitor keeps the guest id
- **WHEN** a visitor whose session holds guest id "guest-a" opens `/`
- **THEN** the session still holds "guest-a" and the Talk screen shows guest-a's turns

### Requirement: Guests are isolated
Every read and write of turns and Progress SHALL be filtered by the guest id. Two guests SHALL never see each other's turns or Progress, and the agent, its tools and the Spoiler horizon SHALL use the asking guest's Progress.

#### Scenario: Two guests, two Conversations
- **WHEN** guest A asks a Question and guest B opens the Talk screen
- **THEN** A's Conversation has the turn and B's Conversation has no turns
- **AND** A and B are served by two different Conversation processes

#### Scenario: Progress per guest
- **WHEN** guest A's Progress has badge 1 and guest B is new
- **THEN** the agent's system prompt for A names Brawly as the Next gym and for B names Roxanne

### Requirement: Start fresh
The Talk screen SHALL have a "Start fresh" button. Pressing it SHALL show an in-page confirm step (no browser dialog). Confirming SHALL give the browser a new guest id, so it gets a new empty Conversation and seed Progress. The previous guest's rows SHALL stay in Postgres.

#### Scenario: Confirm step
- **WHEN** the visitor presses "Start fresh"
- **THEN** a confirm form that posts to `/fresh` and a way to cancel are shown

#### Scenario: Fresh start rotates the guest id
- **WHEN** a guest with a stored turn confirms Start fresh
- **THEN** the session holds a different guest id and `/` shows no turns
- **AND** the old turn is still stored under the old guest id
