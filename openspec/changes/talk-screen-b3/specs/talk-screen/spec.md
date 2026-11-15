# Spec Delta

## MODIFIED Requirements

### Requirement: Talk screen at the root
The page at `/` SHALL be the Talk screen: a root with id `talk-screen` holding a trainer card with id `trainer-card` at the top, a chat with id `turns` holding the Conversation list with id `conversation` showing recent turns (Question and Answer text) in order, and a Talk button with id `talk-button`. It SHALL keep the strict Content-Security-Policy unchanged: audio travels over the existing LiveView socket only.

#### Scenario: Empty Conversation
- **WHEN** a visitor opens `/` and no turns are stored
- **THEN** `#talk-button` exists and `#conversation` has no `.turn` element

#### Scenario: Stored turns are shown
- **WHEN** a visitor opens `/` and a turn with Question "Where is Ralts" is stored
- **THEN** `#conversation` has one `.turn` whose `.question` reads "Where is Ralts" and whose `.answer` reads the stored Answer

#### Scenario: CSP unchanged
- **WHEN** a visitor opens `/`
- **THEN** the `content-security-policy` header still has `connect-src 'self'` and no new origin

## ADDED Requirements

### Requirement: Trainer card from the Guest's Progress
The trainer card SHALL show Maya's ball, the Guest's location, the Next gym leader with a type chip, the Guest's Team (each member's name, a dot per type and its level) and 8 badge slots with the text "N of 8 badges", all from the Guest's Progress and game data. The gym type is the most common type in the leader's party. It SHALL NOT name any gym past the Next gym.

#### Scenario: Seed Progress
- **WHEN** a new Guest opens `/`
- **THEN** `#trainer-card` shows the location "Littleroot Town"
- **AND** `#next-gym` reads "Next gym: Roxanne" with a `.type-chip` reading "Rock"
- **AND** `#team` has one `.mon` reading "Mudkip Lv 5" with one `.type-dot.type-water`
- **AND** `#badge-count` reads "0 of 8 badges"

#### Scenario: Earned badges move the Next gym
- **WHEN** a Guest whose Progress has badges 1 and 2 opens `/`
- **THEN** `#next-gym` reads "Next gym: Wattson" with a `.type-chip` reading "Electric"
- **AND** `#badge-count` reads "2 of 8 badges" and two slots have `data-earned="true"`
- **AND** the page names no gym leader after Wattson

#### Scenario: All badges earned
- **WHEN** a Guest whose Progress has all 8 badges opens `/`
- **THEN** `#next-gym` reads "All 8 badges earned" and has no `.type-chip`

### Requirement: Talk moment on the screen root
The screen root SHALL carry the current Talk moment in `data-state`, one of `idle`, `recording`, `uploading`, `waiting` and `speaking`, as reported by the Talk button. It starts `idle` and ignores any other value. The Talk button keeps its own `data-state` and changes it at once on press, without waiting for the server.

#### Scenario: Moments follow the Talk button
- **WHEN** the Talk button reports the moments `recording`, `waiting` and `speaking` in turn
- **THEN** `#talk-screen` has `data-state` `recording`, then `waiting`, then `speaking`

#### Scenario: Unknown moment ignored
- **WHEN** the Talk button reports the moment `dancing`
- **THEN** `#talk-screen` keeps its previous `data-state`

#### Scenario: Latency path unchanged
- **WHEN** a Question is asked
- **THEN** the mic release and playback start timings are still reported per stage, and Answer audio plays from the pushed events without waiting for a moment report

### Requirement: Moment visuals and status
The card SHALL shrink to a slim strip while `recording`, `uploading` and `waiting`, and be full while `idle` and `speaking`. The ring on Maya's ball SHALL pulse coral while `recording`, spin gold while `uploading` or `waiting`, and glow green with a sound wave while `speaking`; under reduced motion none of them animate. A status line with id `talk-status` SHALL be an aria-live region reading the moment as text.

#### Scenario: Status per moment
- **WHEN** `#talk-screen` is `idle`, `recording`, `waiting` and `speaking` in turn
- **THEN** `#talk-status` (with `role="status"`) reads "Ready when you are", "Listening to you…", "Thinking…" and "Maya is speaking"

#### Scenario: Wave only while speaking
- **WHEN** `#talk-screen` is `speaking`
- **THEN** `#talk-status` contains a `.wave` hidden from screen readers

### Requirement: Short chat
The chat SHALL show only the last 3 turns: the Guest's Question on the right, Maya's Answer on the left, the latest turn marked as current with its Answer in the largest text and older turns faded. A Question of "(nothing heard)" SHALL read as a friendly line instead.

#### Scenario: Last three exchanges
- **WHEN** a Guest with 5 stored turns opens `/`
- **THEN** `#conversation` has 3 `.turn` elements, the last 3 in order, and only the last has the class `now`

#### Scenario: Nothing heard
- **WHEN** a stored turn has the Question "(nothing heard)"
- **THEN** its `.question` has the class `nothing-heard` and reads "Maya did not hear anything that time"

### Requirement: Talk button in the thumb zone
The Talk button SHALL stay pinned at the bottom of the viewport, above the safe area, at least 44 px tall, with an inline SVG mic icon hidden from screen readers and one label per moment: "Hold to talk" (idle), "Release to send" (recording), "One sec…" (uploading and waiting) and "Hold to cut in" (speaking), plus a hint line with id `talk-hint`. Start fresh SHALL stay reachable on the screen.

#### Scenario: Button parts
- **WHEN** a visitor opens `/`
- **THEN** `#talk-button` contains an `svg` with `aria-hidden="true"`, a `#talk-hint`, and one label for each of the four moments
- **AND** `#start-fresh-button` exists
