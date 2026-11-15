# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: Talk screen at the root`
- TO: `### Requirement: Talk screen at /talk`

## ADDED Requirements

### Requirement: Talk screen open to Guests
`/talk` SHALL be open to every Guest without a login (the friends login is deferred, see #49). `POST /fresh` stays as it is and returns to the Talk screen. The home page `/`, `/health` and static assets SHALL stay public.

#### Scenario: Guest opens the Talk screen
- **WHEN** a visitor requests `/talk`
- **THEN** the response is 200 and the page has `#talk-screen`

#### Scenario: Start fresh returns to the Talk screen
- **WHEN** a Guest posts to `/fresh`
- **THEN** the response redirects to `/talk`

#### Scenario: Public routes stay public
- **WHEN** a visitor requests `/`, `/health` or `/images/backdrops/tide.jpg`
- **THEN** each response is 200

### Requirement: Talk heading
The Talk screen SHALL have exactly one top-level heading, "Talk to Maya", with id `talk-heading`, visually hidden so it does not repeat the header, and a header link "Maya" to `/`.

#### Scenario: Heading on the Talk screen
- **WHEN** a Guest opens `/talk`
- **THEN** the page has one `h1`, `#talk-heading`, reading "Talk to Maya"
- **AND** the header link to `/` reads "Maya"

### Requirement: Talk screen kept out of search engines
The Talk screen SHALL carry `<meta name="robots" content="noindex, nofollow">`, and `/robots.txt` SHALL disallow `/talk` and `/fresh`.

#### Scenario: noindex on the Talk screen
- **WHEN** a Guest opens `/talk`
- **THEN** the page has `meta[name="robots"]` with content "noindex, nofollow"

### Requirement: Rotating Poké facts on the Talk screen
While the Conversation is empty, the Talk screen SHALL show a list `#poke-facts` of 10 to 14 spoiler-free `.poke-fact` items in the server-rendered HTML, naming only the Hoenn starters and wild Pokémon before the first gym, never an evolved starter. The rotation SHALL be CSS only, with no script in the page content and no animation under reduced motion. Once the Conversation has a turn, the facts are not shown.

#### Scenario: Facts are listed
- **WHEN** a visitor opens `/talk` and the Conversation is empty
- **THEN** the element `#poke-facts` exists
- **AND** it contains between 10 and 14 elements with class `poke-fact`
- **AND** every `.poke-fact` has non-empty text

#### Scenario: Facts stay spoiler-free
- **WHEN** a visitor opens `/talk`
- **THEN** the "No spoilers" scenario of the badge case still holds for the whole page, facts included
- **AND** no `.poke-fact` names an evolved form of a Hoenn starter (Grovyle, Sceptile, Combusken, Blaziken, Marshtomp, Swampert)

#### Scenario: No script for the rotation
- **WHEN** a visitor opens `/talk`
- **THEN** the page content (`main`) contains no `script` element

#### Scenario: Facts hidden once the Conversation starts
- **WHEN** a visitor opens `/talk` and the Conversation has a turn
- **THEN** the page has no `#poke-facts`

### Requirement: Emerald ball in the trainer card
The Talk screen SHALL show an Emerald edition Poké Ball (green, white and black) drawn in CSS without images, in an element with id `pokeball` and class `pokeball-emerald`, inside the trainer card `#trainer-card`. The old hero `#maya-hero` SHALL NOT be shown.

#### Scenario: Poké Ball is present
- **WHEN** a visitor opens `/talk`
- **THEN** the element `#pokeball` exists
- **AND** it contains no `img` element

#### Scenario: Emerald ball in the trainer card
- **WHEN** a visitor opens `/talk`
- **THEN** `#trainer-card #pokeball` has the class `pokeball-emerald`
- **AND** the page has no `#maya-hero`

### Requirement: Badge case on the Talk screen
The Talk screen SHALL show, in the trainer card, a badge case with id `badge-case` holding exactly 8 badge slots, each labelled only by its number and marked earned or not from the Guest's Progress. It SHALL NOT name any badge, and SHALL NOT name any gym or gym leader past the Guest's Next gym. The badge case stays shown once the Conversation has a turn.

#### Scenario: Eight empty slots
- **WHEN** a new Guest opens `/talk`
- **THEN** `#badge-case` contains exactly 8 elements with class `badge-slot`
- **AND** every slot has `data-earned="false"`
- **AND** the slots are labelled "Badge 1 of 8" through "Badge 8 of 8"

#### Scenario: No spoilers
- **WHEN** a new Guest opens `/talk`
- **THEN** the page names Roxanne, the Next gym, and none of the later Hoenn gym leaders (Brawly, Wattson, Flannery, Norman, Winona, Tate, Liza, Juan)
- **AND** none of the Hoenn badge names (Stone, Knuckle, Dynamo, Heat, Balance, Feather, Mind, Rain) followed by "Badge"

#### Scenario: Shown once the Conversation starts
- **WHEN** a visitor opens `/talk` and the Conversation has a turn
- **THEN** the page still has `#badge-case`

## MODIFIED Requirements

### Requirement: Talk screen at /talk
The page at `/talk` SHALL be the Talk screen: a root with id `talk-screen` holding a trainer card with id `trainer-card` at the top, a chat with id `turns` holding the Conversation list with id `conversation` showing recent turns (Question and Answer text) in order, and a Talk button with id `talk-button`. It SHALL keep the strict Content-Security-Policy unchanged: audio travels over the existing LiveView socket only.

#### Scenario: Empty Conversation
- **WHEN** a visitor opens `/talk` and no turns are stored
- **THEN** `#talk-button` exists and `#conversation` has no `.turn` element

#### Scenario: Stored turns are shown
- **WHEN** a visitor opens `/talk` and a turn with Question "Where is Ralts" is stored
- **THEN** `#conversation` has one `.turn` whose `.question` reads "Where is Ralts" and whose `.answer` reads the stored Answer

#### Scenario: CSP unchanged
- **WHEN** a visitor opens `/talk`
- **THEN** the `content-security-policy` header still has `connect-src 'self'` and no new origin

### Requirement: Talk button state machine
The Talk button SHALL run as an explicit state machine with the states `idle`, `recording`, `uploading`, `waiting` and `speaking`, shown in its `data-state` attribute. Pressing and holding records; releasing sends exactly one Question as one upload. Pressing while `speaking` is a barge-in that stops audio at once and starts recording. The button SHALL report the mic release and playback start timings back to the server.

#### Scenario: Idle on load
- **WHEN** a visitor opens `/talk`
- **THEN** `#talk-button` has `data-state="idle"` and is bound to the Talk hook

#### Scenario: One upload per hold
- **WHEN** one clip is uploaded as the Question
- **THEN** the Conversation receives exactly one Question
- **AND** the upload accepts at most one entry of at most 1 MB

### Requirement: Trainer card from the Guest's Progress
The trainer card SHALL show Maya's ball, the Guest's location, the Next gym leader with a type chip, the Guest's Team (each member's name, a dot per type and its level) and 8 badge slots with the text "N of 8 badges", all from the Guest's Progress and game data. The gym type is the most common type in the leader's party. It SHALL NOT name any gym past the Next gym.

#### Scenario: Seed Progress
- **WHEN** a new Guest opens `/talk`
- **THEN** `#trainer-card` shows the location "Littleroot Town"
- **AND** `#next-gym` reads "Next gym: Roxanne" with a `.type-chip` reading "Rock"
- **AND** `#team` has one `.mon` reading "Mudkip Lv 5" with one `.type-dot.type-water`
- **AND** `#badge-count` reads "0 of 8 badges"

#### Scenario: Earned badges move the Next gym
- **WHEN** a Guest whose Progress has badges 1 and 2 opens `/talk`
- **THEN** `#next-gym` reads "Next gym: Wattson" with a `.type-chip` reading "Electric"
- **AND** `#badge-count` reads "2 of 8 badges" and two slots have `data-earned="true"`
- **AND** the page names no gym leader after Wattson

#### Scenario: All badges earned
- **WHEN** a Guest whose Progress has all 8 badges opens `/talk`
- **THEN** `#next-gym` reads "All 8 badges earned" and has no `.type-chip`

### Requirement: Short chat
The chat SHALL show only the last 3 turns: the Guest's Question on the right, Maya's Answer on the left, the latest turn marked as current with its Answer in the largest text and older turns faded. A Question of "(nothing heard)" SHALL read as a friendly line instead.

#### Scenario: Last three exchanges
- **WHEN** a Guest with 5 stored turns opens `/talk`
- **THEN** `#conversation` has 3 `.turn` elements, the last 3 in order, and only the last has the class `now`

#### Scenario: Nothing heard
- **WHEN** a stored turn has the Question "(nothing heard)"
- **THEN** its `.question` has the class `nothing-heard` and reads "Maya did not hear anything that time"

### Requirement: Talk button in the thumb zone
The Talk button SHALL stay pinned at the bottom of the viewport, above the safe area, at least 44 px tall, with an inline SVG mic icon hidden from screen readers and one label per moment: "Hold to talk" (idle), "Release to send" (recording), "One sec…" (uploading and waiting) and "Hold to cut in" (speaking), plus a hint line with id `talk-hint`. Start fresh SHALL stay reachable on the screen.

#### Scenario: Button parts
- **WHEN** a visitor opens `/talk`
- **THEN** `#talk-button` contains an `svg` with `aria-hidden="true"`, a `#talk-hint`, and one label for each of the four moments
- **AND** `#start-fresh-button` exists
