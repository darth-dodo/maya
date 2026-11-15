# talk-screen Specification

## Purpose
The screen at `/talk` the player talks to Maya on: the trainer card, the Talk button and its state machine, the Talk moment on the screen, the short chat and the voice down note.

## Requirements

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

### Requirement: Hold end
The first `pointerup` or `pointercancel` SHALL end a hold and any later one SHALL do nothing; a lost pointer capture alone SHALL NOT end a hold. A server re-render SHALL NOT change the button's own state. Each hold SHALL report how it ended (`pointerup` or `pointercancel`), its length in ms, whether capture was lost first, whether the press was warm and its post-roll, and the server SHALL log that report at info level with no audio or text; any other report is ignored.

#### Scenario: Hold end logged
- **WHEN** the Talk button reports a hold that ended by `pointercancel` after 840 ms with capture lost, a cold press, the mic live after 120 ms and a 150 ms post-roll
- **THEN** the server logs "hold ended by pointercancel after 840 ms, lost capture: true, mic open: 120 ms, warm: false, post roll: 150 ms" at info level

#### Scenario: Warm hold logged
- **WHEN** the Talk button reports a warm hold that ended by `pointerup` after 1500 ms with a 150 ms post-roll
- **THEN** the server logs "hold ended by pointerup after 1500 ms, lost capture: false, mic open: 0 ms, warm: true, post roll: 150 ms"

#### Scenario: Hold ended before the mic was live
- **WHEN** the Talk button reports a cold hold that ended by `pointerup` after 60 ms with no mic open time and no post-roll
- **THEN** the server logs "hold ended by pointerup after 60 ms, lost capture: false, mic open: none, warm: false, post roll: 0 ms"

#### Scenario: Bad hold end report ignored
- **WHEN** the Talk button reports a hold with an unknown ending, a length that is not a non-negative integer, a `warm` that is not a boolean, or a `post_roll_ms` that is not a non-negative integer
- **THEN** nothing is logged and the screen is unchanged

#### Scenario: Server moment does not drive the button
- **WHEN** the Talk button reports the moment `recording`
- **THEN** `#talk-screen` has `data-state="recording"` and the server renders `#talk-button` only with its static `data-state="idle"`, which the Talk hook replaces with its own

### Requirement: Mic only while held
The Talk button SHALL open the mic on a press when it is closed and enter `recording` only once the stream is live. An open mic SHALL stay open while a turn is in flight and stop every track 4 s after the button is back to `idle` with no new press, and at once when the page is hidden or destroyed. While open with no hold it SHALL keep only a 300 ms pre-roll and send nothing; a press on an open mic SHALL start with it. A hold that ends before the mic is live SHALL send no Question.

#### Scenario: Warm press keeps the first syllable
- **WHEN** the mic is open and idle with 300 ms of pre-roll, and a Guest presses and holds for 2000 ms
- **THEN** the Question clip is at least 2300 ms long and starts with the pre-roll samples
- **AND** the button enters `recording` on the press, with no wait for the mic

#### Scenario: Pre-roll keeps only the window
- **WHEN** the mic has been open and idle for 5 seconds with a 300 ms pre-roll
- **THEN** the hook holds at most 300 ms of samples, and nothing was sent to the server

#### Scenario: Mic off after each hold
- **WHEN** a Guest's turn ends (Maya finished speaking, or voice is down) and there is no new press
- **THEN** the mic tracks are stopped within 4 seconds of the button returning to `idle`, and the phone's mic indicator turns off within about 5 seconds
- **AND** the next press opens the mic again as a cold press

#### Scenario: Cold press
- **WHEN** the mic is closed and a Guest presses
- **THEN** the button enters `recording` only once the stream is live and the clip has no pre-roll

#### Scenario: Hidden page closes the mic
- **WHEN** the mic is open and the page becomes hidden
- **THEN** every mic track is stopped at once

### Requirement: Voice down note
When the voice is down the Talk screen SHALL show the note "voice is down" next to the affected turn, or on its own when no Question was heard.

#### Scenario: Note shown
- **WHEN** the Conversation reports that TTS failed for a turn
- **THEN** that `.turn` contains an element `.voice-down` with the text "voice is down"

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
The card SHALL shrink to a slim strip while `uploading` and `waiting`, and be full while `idle`, `recording` and `speaking`, so nothing moves under a held finger. The ring on Maya's ball SHALL pulse coral while `recording`, spin gold while `uploading` or `waiting`, and glow green with a sound wave while `speaking`; under reduced motion none of them animate. A status line with id `talk-status` SHALL be an aria-live region reading the moment as text.

#### Scenario: Status per moment
- **WHEN** `#talk-screen` is `idle`, `recording`, `waiting` and `speaking` in turn
- **THEN** `#talk-status` (with `role="status"`) reads "Ready when you are", "Listening to you…", "Thinking…" and "Maya is speaking"

#### Scenario: Wave only while speaking
- **WHEN** `#talk-screen` is `speaking`
- **THEN** `#talk-status` contains a `.wave` hidden from screen readers

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

### Requirement: Post-roll after release
On release of a live hold the Talk button SHALL enter `uploading` at once, SHALL keep recording into the Question for the post-roll (default 150 ms, set by `data-post-roll-ms` on `#talk-button`), and only then SHALL upload the clip, so a last word clipped by an early release is kept.

#### Scenario: Post-roll keeps the last word
- **WHEN** a Guest releases a live hold right as they finish speaking, with a 150 ms post-roll
- **THEN** the button enters `uploading` at once, with no visible delay
- **AND** the Question clip includes the 150 ms after the release and uploads only after it

#### Scenario: Post-roll is set on the button
- **WHEN** the Talk screen renders
- **THEN** `#talk-button` has `data-post-roll-ms="150"`

### Requirement: Warm mic latency and accuracy evidence
The warm mic change SHALL not add work on the server path, and its PR SHALL show the effect on clipping and latency with numbers from real phone holds.

#### Scenario: Latency unchanged and first words kept
- **WHEN** 10 holds are made on a phone before and after the change, each Question starting with a Pokémon name spoken at the press
- **THEN** the PR shows per-stage p50 for `mic_release_ms`, `stt_ms`, `agent_ms`, `tts_first_byte_ms` and `playback_start_ms` before and after, with no stage more than 100 ms slower, apart from the post-roll's own 150 ms on `mic_release_ms` and `playback_start_ms`, which the PR states
- **AND** the PR shows how many of the 10 transcripts kept the first word and the last word (released right as the Guest finishes speaking) before and after, and the warm press `mic_open_ms` is 0
