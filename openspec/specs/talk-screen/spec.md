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
The Talk button SHALL run as a state machine (`idle`, `recording`, `uploading`, `waiting`, `speaking`) shown in its `data-state`. A hold SHALL stream 16 kHz mono 16-bit PCM chunks of 100 to 250 ms, then an end of stream on release: one hold, one Question. Pressing while `speaking` SHALL stop audio at once and start a new stream. The button SHALL report mic release and playback start timings.

#### Scenario: Idle on load
- **WHEN** a visitor opens `/`
- **THEN** `#talk-button` has `data-state="idle"` and is bound to the Talk hook

#### Scenario: One upload per hold
- **WHEN** the button sends a stream start, 8 chunks and a stream end
- **THEN** the Conversation receives exactly one Question and no file upload is made
- **AND** a second stream end for the same hold is ignored

#### Scenario: Chunk size
- **WHEN** a 2 second hold is streamed
- **THEN** every chunk but the last holds 1600 to 4000 samples (100 to 250 ms at 16 kHz)

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

#### Scenario: Phone audio handed back after the mic closes
- **WHEN** the mic closes (idle delay, hidden page or destroyed) while the button is `idle` and no Answer audio is playing
- **THEN** the hook suspends its AudioContext and, where `navigator.audioSession` exists, sets its type back to `"auto"` (it is `"play-and-record"` while the mic is open), so music another app was playing can resume
- **AND** the next press resumes the AudioContext inside the gesture, before the mic opens

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
The chat SHALL show only the last 3 turns, unboxed on the page, styled like the homepage real turn: every Question small, right aligned and muted, every Answer on the left, with no bubble background or border and a `--maya-line` hairline between turns. Older Answers SHALL use the muted colour at body size; the latest turn is marked as current and its Answer is the largest text on the screen, about 24px. A Question of "(nothing heard)" SHALL read as a friendly line instead.

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

#### Scenario: Questions like the homepage
- **WHEN** `/talk` renders at 375px wide with 3 stored turns, in either theme
- **THEN** every `.question` is right aligned, has the computed colour of `--maya-muted` and the same computed font size as `#real-turn-question` on `/`

#### Scenario: Latest Answer largest
- **WHEN** `/talk` renders at 375px wide with 3 stored turns
- **THEN** `.turn.now .answer` has a computed font size between 22 and 26px, the colour of `--maya-ink`, larger than every other text on the screen except the gym line
- **AND** older `.answer` elements have the body size and the computed colour of `--maya-muted`

### Requirement: Talk button in the thumb zone
The Talk button SHALL stay pinned at the bottom of the viewport, above the safe area, as a full-width pill 72px tall, with an inline SVG mic icon hidden from screen readers and one label per moment: "Hold to talk" (idle), "Release to send" (recording), "One sec…" (uploading and waiting) and "Hold to cut in" (speaking), plus a hint line with id `talk-hint`. Start fresh SHALL stay reachable on the screen.

#### Scenario: Button parts
- **WHEN** a visitor opens `/talk`
- **THEN** `#talk-button` contains an `svg` with `aria-hidden="true"`, a `#talk-hint`, and one label for each of the four moments
- **AND** `#start-fresh-button` exists

#### Scenario: Pill size
- **WHEN** `/talk` renders at 375px wide
- **THEN** `#talk-button` has a computed height of 72px, a width of at least 375px minus 32px of gutters, and the radius `--maya-radius-pill`

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
The Talk screen SHALL have exactly one top-level heading, "Talk to Maya", with id `talk-heading`, visually hidden so it does not repeat the header, a header link "Maya" to `/` and a header link "Home" to `/`.

#### Scenario: Heading on the Talk screen
- **WHEN** a Guest opens `/talk`
- **THEN** the page has one `h1`, `#talk-heading`, reading "Talk to Maya"
- **AND** the header link to `/` reads "Maya"
- **AND** `#header-home-link` reads "Home" and links to `/`

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

### Requirement: Live transcript bubble
While a hold streams, the Talk screen SHALL show the partial transcript in a Guest bubble `#live-question`, updated as text arrives, and SHALL replace it with the pending Question when the final transcript is ready. The bubble SHALL be in the conversation's polite live region.

#### Scenario: Live words while held
- **WHEN** the Conversation reports the partial text "where do I catch"
- **THEN** `#live-question` contains "where do I catch"

#### Scenario: Live bubble replaced on final
- **WHEN** the final transcript "where do I catch Ralts?" is ready
- **THEN** `#live-question` is gone and `#pending-question` contains "where do I catch Ralts?"

### Requirement: Talk screen follows the design system

The Talk screen SHALL take every colour, font, radius, shadow and transition from the Maya design tokens and SHALL follow the active theme: Calm Emerald by day and Emerald night at night, with the glow on Maya's ball only at night and no gold hairline on the trainer info. Headings and the gym line SHALL use the heading font; Answers, buttons and labels SHALL use the body font. Only state changes SHALL move.

#### Scenario: Night look

- **WHEN** `/talk` renders with `data-theme="dark"`
- **THEN** the page background computes to the night `--maya-bg` (`#08181a`), `#trainer-card` has no bottom border, and Maya's ball has a box shadow glow

#### Scenario: Day look

- **WHEN** `/talk` renders with `data-theme="light"`
- **THEN** the page background computes to the day `--maya-bg` (`#f6f1e7`), the Talk button background computes to `--maya-action` (`#0f5a3a`), and `#trainer-card` has no border

#### Scenario: Fonts on the Talk screen

- **WHEN** `/talk` renders in either theme
- **THEN** the Talk heading's and `#next-gym`'s computed font families start with "Fraunces" and the latest Answer's starts with "Inter"

#### Scenario: Behaviour unchanged

- **WHEN** the existing Talk screen and voice loop tests run after the change
- **THEN** they all pass with no edits to their assertions about states, mic handling or the voice loop
- **AND** `assets/js/talk_hook.js` has no diff

### Requirement: Slim header over tide art
The trainer info `#trainer-card` SHALL sit in the same tide art band as the homepage hero, smaller: tide art by day and night art at night from `/images/backdrops/`, full strength at the top and fading into `--maya-bg`, so its text sits on `--maya-bg`. It SHALL show Maya's ball, about 60px, left of an eyebrow with the location and badge count and the Next gym line in the heading font, then the Team as chips that wrap.

#### Scenario: Header parts
- **WHEN** a new Guest opens `/talk`
- **THEN** `#trainer-card` contains `#location`, `#badge-count`, `#next-gym`, `#team`, `#badge-case` and `#pokeball`
- **AND** `#location` and `#badge-count` are inside one element `#card-eyebrow`

#### Scenario: Art per theme
- **WHEN** `/talk` renders with `data-theme="light"` and again with `data-theme="dark"`
- **THEN** the computed background image of `#trainer-card` uses `/images/backdrops/tide.jpg` and `/images/backdrops/night.jpg` respectively

#### Scenario: Art stays faint
- **WHEN** `/talk` renders at 375px wide in either theme
- **THEN** the fade over the art in `#trainer-card` reaches opaque `--maya-bg` at or above the top of `#card-eyebrow` and of `#pokeball`, written with tokens and no colour literal
- **AND** `#trainer-card` is shorter than `#home-hero` at the same width

#### Scenario: Ball beside the eyebrow
- **WHEN** `/talk` renders at 375px wide
- **THEN** `#pokeball` is between 56 and 64px wide and its right edge is left of the left edge of `#card-eyebrow`

#### Scenario: Eyebrow separator on older Safari
- **WHEN** the Talk block of `assets/css/app.css` is read
- **THEN** the rule that puts "·" before `#badge-count` declares a plain `content: "·";` before the `content: "·" / "";` line

#### Scenario: Team chips wrap
- **WHEN** `/talk` renders at 375px wide for a Guest with 6 Team members
- **THEN** `#team` has a computed `flex-wrap` of `wrap`, its scroll width is not larger than its client width, and the page has no horizontal scroll

### Requirement: Talk screen without containers
The Talk screen SHALL sit directly on the page: `#talk-screen` SHALL have no border, no corner radius and no background image, on a full bleed `--maya-bg`, and the trainer info `#trainer-card` SHALL have no border, no corner radius and no box shadow. The page SHALL not scroll sideways at 375px.

#### Scenario: No scene panel
- **WHEN** `/talk` renders at 375px wide with `data-theme="light"` and again with `data-theme="dark"`
- **THEN** `#talk-screen` has a computed border width of 0, a border radius of 0 and a background image of `none`
- **AND** the `body` background computes to that theme's `--maya-bg`

#### Scenario: No card box
- **WHEN** `/talk` renders in either theme
- **THEN** `#trainer-card` has a computed border width of 0 on every side, a border radius of 0 and a box shadow of `none`

#### Scenario: No sideways scroll
- **WHEN** `/talk` renders at 375px wide for a Guest with 6 Team members and 3 stored turns
- **THEN** the document scroll width is not larger than 375px

#### Scenario: Nothing changes size between moments
- **WHEN** `/talk` renders at 375px wide and `#talk-screen` `data-state` is set to `idle`, `recording`, `waiting` and `speaking` in turn
- **THEN** the computed heights of `#site-header`, `#trainer-card` and `#talk-button` are the same in every moment
