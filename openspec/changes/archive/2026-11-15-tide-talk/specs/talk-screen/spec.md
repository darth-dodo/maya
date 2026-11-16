## MODIFIED Requirements

### Requirement: Moment visuals and status
The trainer card SHALL keep the same height in every moment (`idle`, `recording`, `uploading`, `waiting`, `speaking`), so nothing moves under a held finger. The ring on Maya's ball SHALL pulse coral while `recording`, spin gold while `uploading` or `waiting`, and glow green with a sound wave while `speaking`; under reduced motion none of them animate. A status line with id `talk-status` SHALL be an aria-live region reading the moment as text.

#### Scenario: Status per moment
- **WHEN** `#talk-screen` is `idle`, `recording`, `waiting` and `speaking` in turn
- **THEN** `#talk-status` (with `role="status"`) reads "Ready when you are", "Listening to you…", "Thinking…" and "Maya is speaking"

#### Scenario: Wave only while speaking
- **WHEN** `#talk-screen` is `speaking`
- **THEN** `#talk-status` contains a `.wave` hidden from screen readers

#### Scenario: Header height fixed
- **WHEN** `/talk` renders at 375px wide and `#talk-screen` `data-state` is set to `idle`, `recording`, `waiting` and `speaking` in turn
- **THEN** the computed height of `#trainer-card` is the same in every moment, and the `top` of `#talk-button` does not change

#### Scenario: Latency unchanged
- **WHEN** 5 holds are made on a phone before and after the change
- **THEN** the PR shows per-stage p50 for `mic_release_ms`, `stt_ms`, `agent_ms`, `tts_first_byte_ms` and `playback_start_ms` before and after, with no stage more than 100 ms slower

### Requirement: Short chat
The chat SHALL show only the last 3 turns, unboxed: the Guest's Question on the right and Maya's Answer on the left, with no bubble background or border, and a hairline between turns. Older turns SHALL use the muted colour at body size; the latest turn is marked as current and its Answer is the largest text on the screen, about 24px. A Question of "(nothing heard)" SHALL read as a friendly line instead.

#### Scenario: Last three exchanges
- **WHEN** a Guest with 5 stored turns opens `/talk`
- **THEN** `#conversation` has 3 `.turn` elements, the last 3 in order, and only the last has the class `now`

#### Scenario: Nothing heard
- **WHEN** a stored turn has the Question "(nothing heard)"
- **THEN** its `.question` has the class `nothing-heard` and reads "Maya did not hear anything that time"

#### Scenario: Unboxed with hairlines
- **WHEN** `/talk` renders with 3 stored turns, in either theme
- **THEN** no `.question` or `.answer` has a computed background other than transparent, a border or a box shadow
- **AND** each `.turn` after the first has a computed top border in that theme's `--maya-line`

#### Scenario: Latest Answer largest
- **WHEN** `/talk` renders at 375px wide with 3 stored turns
- **THEN** `.turn.now .answer` has a computed font size between 22 and 26px, larger than every other text on the screen except the gym line
- **AND** older `.answer` and `.question` elements have the body size and the computed colour of `--maya-muted`

### Requirement: Talk button in the thumb zone
The Talk button SHALL stay pinned at the bottom of the viewport, above the safe area, as a full-width pill 72px tall, with an inline SVG mic icon hidden from screen readers and one label per moment: "Hold to talk" (idle), "Release to send" (recording), "One sec…" (uploading and waiting) and "Hold to cut in" (speaking), plus a hint line with id `talk-hint`. Start fresh SHALL stay reachable on the screen.

#### Scenario: Button parts
- **WHEN** a visitor opens `/talk`
- **THEN** `#talk-button` contains an `svg` with `aria-hidden="true"`, a `#talk-hint`, and one label for each of the four moments
- **AND** `#start-fresh-button` exists

#### Scenario: Pill size
- **WHEN** `/talk` renders at 375px wide
- **THEN** `#talk-button` has a computed height of 72px, a width of at least 375px minus 32px of gutters, and the radius `--maya-radius-pill`

## ADDED Requirements

### Requirement: Slim header over tide art
The trainer card SHALL be a slim header over faint tide art by day and faint night art at night, both from `/images/backdrops/`. It SHALL show an eyebrow with the location and the badge count, the Next gym line in the heading font, and the Team as chips that wrap onto a new line instead of scrolling. Text in it SHALL keep 4.5:1 contrast against the art.

#### Scenario: Header parts
- **WHEN** a new Guest opens `/talk`
- **THEN** `#trainer-card` contains `#location`, `#badge-count`, `#next-gym`, `#team`, `#badge-case` and `#pokeball`
- **AND** `#location` and `#badge-count` are inside one element `#card-eyebrow`

#### Scenario: Art per theme
- **WHEN** `/talk` renders with `data-theme="light"` and again with `data-theme="dark"`
- **THEN** the computed background image of `#trainer-card` uses `/images/backdrops/tide.jpg` and `/images/backdrops/night.jpg` respectively

#### Scenario: Art stays faint
- **WHEN** the Talk block of `assets/css/app.css` is read
- **THEN** the `#trainer-card` background lays a `--maya-bg` scrim of at least 85% over the art, written with `color-mix()` and no colour literal

#### Scenario: Team chips wrap
- **WHEN** `/talk` renders at 375px wide for a Guest with 6 Team members
- **THEN** `#team` has a computed `flex-wrap` of `wrap`, its scroll width is not larger than its client width, and the page has no horizontal scroll
