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
The first `pointerup` or `pointercancel` of the pressing pointer, wherever on the page it lands, SHALL end a hold and any later one SHALL do nothing; another pointer's SHALL NOT end it, and a lost pointer capture alone SHALL NOT end a hold. A server re-render SHALL NOT change the button's own state.

#### Scenario: Lift off the button after a lost capture
- **WHEN** the Talk button is recording, its pointer capture is lost, and the same finger lifts over another element
- **THEN** the hold ends once by `pointerup` with lost capture true, the clip is sent, the button leaves `recording`, and the mic closes after the normal idle delay once the turn is back to idle

#### Scenario: Server moment does not drive the button
- **WHEN** the Talk button reports the moment `recording`
- **THEN** `#talk-screen` has `data-state="recording"` and the server renders `#talk-button` only with its static `data-state="idle"`, which the Talk hook replaces with its own

### Requirement: Hold end report
Each hold SHALL report how it ended (`pointerup` or `pointercancel`), its length in ms, whether capture was lost first, whether the press was warm and its post-roll, and the server SHALL log that report at info level with no audio or text; any other report is ignored.

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
- **THEN** the hook suspends its AudioContext and, where `navigator.audioSession` exists, sets its type back to `"auto"` (it is `"play-and-record"` while the mic is open; the `?audio_debug=1` picker can choose another after-turn type), so music another app was playing can resume
- **AND** the next press resumes the AudioContext inside the gesture, before the mic opens

#### Scenario: Cold press
- **WHEN** the mic is closed and a Guest presses
- **THEN** the button enters `recording` only once the stream is live and the clip has no pre-roll

#### Scenario: Hidden page closes the mic
- **WHEN** the mic is open and the page becomes hidden
- **THEN** every mic track is stopped at once

### Requirement: Audio session follows the mic
Where `navigator.audioSession` exists the Talk hook SHALL set its type to `"play-and-record"` while the mic is open, `"playback"` while Maya talks with the mic closed, and the after-turn type (`"auto"` by default) once the mic closes (#96). A missing API or a throwing setter SHALL change nothing.

#### Scenario: Silent switch
- **WHEN** Maya talks with the mic closed and `navigator.audioSession` exists
- **THEN** its type is `"playback"`, which the iOS silent switch does not mute; with the mic open it stays `"play-and-record"`

#### Scenario: After-turn type picker (music spike)
- **WHEN** `/talk` is opened with `?audio_debug=1`
- **THEN** a fixed readout shows whether `navigator.audioSession` exists, its type and the AudioContext state, with a picker for the after-turn type (`auto`, `transient`, `ambient`) kept in sessionStorage for the tab
- **AND** without the flag no readout is shown and the after-turn type is `"auto"`

### Requirement: Answer audio never hangs silent
Every press, release and pushed chunk SHALL resume the AudioContext from any state but `running` or `closed`, Safari's `interrupted` included, and swallow a refused resume. The button SHALL never stay in `speaking` with no sound (#96).

#### Scenario: Wake from interrupted
- **WHEN** the AudioContext is `interrupted` (a call, Siri or other audio) and a Guest presses
- **THEN** the hook calls `resume()` inside the gesture, and a refused resume throws nothing

#### Scenario: Playback stall
- **WHEN** Answer audio is queued, the page is visible and the AudioContext clock has not moved for 2.5 s
- **THEN** the hook stops the audio, reports `playback_stalled` with the context state and returns to `idle`
- **AND** the server cuts the turn, logs "playback stalled, context: <state>" (an unknown state as "unknown") and shows the note "voice is down"

#### Scenario: Hidden mid-Answer
- **WHEN** the page becomes hidden while the button is `waiting` or `speaking`, or a chunk arrives while hidden
- **THEN** the hook stops the audio, sends `barge_in` and returns to `idle`; the Answer stays as text

### Requirement: Answer audio by turn id
Each hold SHALL send its own turn id with the stream start, the server SHALL echo it on that turn's `audio` and `audio_done`, and the hook SHALL play only audio carrying the current turn id (#96).

#### Scenario: Late chunks of a cut turn
- **WHEN** a Guest cuts in and the old turn's `audio` or `audio_done` arrives after the new hold's Answer started
- **THEN** the hook drops it by turn id, so no old words play and the new turn does not end early
- **AND** a `stream_start` turn id that is not an integer is dropped by the server, and that hold's audio carries no turn id

### Requirement: Voice down note
When the voice is down the Talk screen SHALL show the note "voice is down" next to the affected turn, or on its own when no Question was heard.

#### Scenario: Note shown
- **WHEN** the Conversation reports that TTS failed for a turn
- **THEN** that `.turn` contains an element `.voice-down` with the text "voice is down"

### Requirement: Talk screen during a database outage
When Postgres cannot be reached as `/talk` opens, the screen SHALL show "Maya can't reach her notes right now. Try again in a minute." with a "Try again" link to `/talk`, in an element with id `notes-down`, and SHALL NOT answer 500 or crash the LiveView. The log SHALL name only the error kind (#192).

#### Scenario: /talk with the database down
- **WHEN** a visitor opens `/talk` and the Progress read fails
- **THEN** the page answers 200 and the connected screen shows `#notes-down` with the line and a "Try again" link, and no `#talk-button`
- **AND** the log says `talk mount failed` with the error kind

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

#### Scenario: An Event updates the card without a reload
- **WHEN** a turn's agent logs an Event (a badge, a catch, an evolution, a level or a place) or undoes one, on a `/talk` screen that stays mounted
- **THEN** the Conversation broadcasts the Guest's Progress on the Guest's topic after the agent stage, once the Answer's TTS has started (never on the path to first sound), and also when a cut ends the agent stage
- **AND** `#badge-count`, `#next-gym`, `#location` and `#team` show it with no page reload, and an undo puts them back
- **AND** an unchanged Progress leaves the card as it is, and a failed Progress read never stops the Answer

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
The chat SHALL show the Conversation's last 25 turns, unboxed on the page, styled like the homepage real turn: every Question small, right aligned and muted, every Answer on the left, with no bubble background or border and a `--maya-line` hairline between turns. Older Answers SHALL use the muted colour at body size; the latest turn is marked as current and its Answer is the largest text on the screen, about 24px. A Question of "(nothing heard)" SHALL read as a friendly line instead.

#### Scenario: Last 25 exchanges
- **WHEN** a Guest with 30 stored turns opens `/talk`
- **THEN** `#conversation` has 25 `.turn` elements, the last 25 in order, and only the last has the class `now`

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

### Requirement: Collapsible Team in the trainer band
The Team in `#trainer-card` SHALL be collapsed by default into one summary line with id `team-summary`, followed by a chevron hidden from screen readers. The line lists Team names in Team order with no levels: up to the first 3 names comma separated, then "+N" for the N remaining members; 3 or fewer members show all names with no "+N"; an empty Team shows "No Team yet". A tap on the summary SHALL show the full Team as `.mon` chips in `#team` and a second tap SHALL fold it back.

#### Scenario: Six members collapsed
- **WHEN** a Guest whose Team is Mudkip, Poochyena, Wingull, Ralts, Zigzagoon and Lotad opens `/talk`
- **THEN** `#team-summary` reads "Mudkip, Poochyena, Wingull +3" and the Team is collapsed
- **AND** `#team` still holds 6 `.mon` elements in the page

#### Scenario: Two members
- **WHEN** a Guest whose Team is Mudkip and Wingull opens `/talk`
- **THEN** `#team-summary` reads "Mudkip, Wingull" with no "+"

#### Scenario: Empty Team
- **WHEN** a Guest whose Team is empty opens `/talk`
- **THEN** `#team-summary` reads "No Team yet"

#### Scenario: Tap to open and close
- **WHEN** a Guest with 6 Team members taps `#team-summary` at 375x667
- **THEN** all 6 `.mon` chips are visible and the summary reports expanded
- **AND** a second tap hides them and the summary reports collapsed

### Requirement: Team summary fits one line and names everyone
The summary SHALL stay one line: when the names do not fit, they SHALL truncate with an ellipsis while the "+N" and the chevron stay fully visible. The summary's accessible name SHALL list the whole Team in order, "Team: " then every name comma separated, so screen readers get every name. It SHALL expose its expanded or collapsed state and be at least 44px tall.

#### Scenario: Six members at 375px
- **WHEN** `/talk` renders at 375x667 for a Guest with 6 Team members whose names do not fit the line
- **THEN** `#team-summary` is one line tall, its names part shows an ellipsis, and the "+3" and the chevron are fully inside the viewport
- **AND** the document scroll width is not larger than 375px

#### Scenario: Accessible name lists the whole Team
- **WHEN** a Guest whose Team is Mudkip, Poochyena, Wingull, Ralts, Zigzagoon and Lotad opens `/talk`
- **THEN** the accessible name of `#team-summary` is "Team: Mudkip, Poochyena, Wingull, Ralts, Zigzagoon, Lotad"

#### Scenario: Tap target and motion
- **WHEN** `/talk` renders at 375px wide in either theme
- **THEN** `#team-summary` has a computed height of at least 44px
- **AND** under `prefers-reduced-motion: reduce` nothing in `#trainer-card` has a transition duration above 0 or an animation
- **AND** `assets/js/talk_hook.js` has no diff

### Requirement: Team open state and steady band
Once open, the Team SHALL stay open through LiveView updates for the rest of the page view; each visit starts collapsed and nothing is stored. A change to the Team SHALL update the summary and the chips and SHALL NOT open or close the list. The Team SHALL use only `--maya-*` tokens in both themes and SHALL NOT animate its height.

#### Scenario: Open survives an update
- **WHEN** the Team is open and the page receives a LiveView update (a Talk moment change, a new turn or a Team change)
- **THEN** the Team is still open after the update

#### Scenario: A catch while collapsed updates the names
- **WHEN** the Team is collapsed as Mudkip and Wingull and the Guest catches Ralts
- **THEN** `#team-summary` reads "Mudkip, Wingull, Ralts" and the Team stays collapsed

#### Scenario: Collapsed band stays short
- **WHEN** `/talk` renders at 375x667 with the Team collapsed, once for a Guest with 1 Team member and once with 6
- **THEN** `#trainer-card` has the same computed height in both, and it is shorter than with the 6 member Team open

#### Scenario: Band steady in every moment
- **WHEN** `/talk` renders at 375px wide, with the Team collapsed and again open, and `#talk-screen` `data-state` is set to `idle`, `recording`, `waiting` and `speaking` in turn
- **THEN** the computed heights of `#trainer-card` and `#talk-button` are the same in every moment within each case

### Requirement: Team editor from a Team chip
Each `.mon` chip in `#team` SHALL be a button whose accessible name is "Edit " then the member's name and level. Tapping it while the Talk moment is idle SHALL open `#team-editor` for that member, with a heading naming it and buttons to change its level, set it as lead, move it to the PC box and remove it, plus a "PC box" button and a Close button. Close, Escape or a tap on another chip SHALL close or switch the editor.

#### Scenario: Open the editor
- **WHEN** a Guest whose Team is Mudkip 16 and Wingull 9 taps the Wingull chip while idle
- **THEN** `#team-editor` is shown with the heading "Wingull Lv 9" and the buttons "Save level", "Set as lead", "Move to PC box", "Remove", "PC box" and "Close"

#### Scenario: Close the editor
- **WHEN** the editor is open and the Guest taps Close or presses Escape
- **THEN** `#team-editor` is gone and focus is back on the chip that opened it

#### Scenario: Not while talking
- **WHEN** `#talk-screen` `data-state` is `recording`, `waiting` or `speaking` and a Team chip is tapped
- **THEN** no editor opens
- **AND** an editor that was open closes when a hold starts

### Requirement: Editor actions write Events
Each editor action SHALL write exactly the Event the same voice request writes (`set_level`, `set_lead`, `deposited`, `released`, `withdrawn`, with the member's `slot`), through the one Events path, so voice and screen give the same Progress. The editor SHALL show the confirm or refused line in a polite live region, update `#team` and the Team summary without a reload, and offer an Undo button after a confirm that logs `undo`.

#### Scenario: Change a level
- **WHEN** the Guest sets Wingull's level to 11 in the editor and taps Save level
- **THEN** one `set_level` Event is written, the chip reads "Wingull Lv 11", and the editor shows "Wingull is level 11 now."

#### Scenario: Level out of range
- **WHEN** the Guest saves level 0 or 101
- **THEN** the editor shows "Levels go from 1 to 100." and no Event is written

#### Scenario: Set as lead
- **WHEN** the Guest taps Set as lead on Wingull
- **THEN** `#team` lists Wingull first and the Team summary starts with "Wingull"

#### Scenario: Move to the PC box
- **WHEN** the Guest taps Move to PC box on Wingull
- **THEN** Wingull's chip is gone, one `deposited` Event is written, and the editor shows "Wingull sent to the PC."

#### Scenario: Remove
- **WHEN** the Guest taps Remove on Wingull
- **THEN** one `released` Event is written, the chip is gone, and the editor shows "Wingull released from the Team."

#### Scenario: Undo
- **WHEN** the Guest taps Undo after any confirmed action
- **THEN** the Team and PC box are as they were before it and `#team` shows that

#### Scenario: The last Team member
- **WHEN** the Team is only Mudkip and the Guest taps Move to PC box
- **THEN** the editor shows "Your Team needs at least one Pokémon." and Mudkip stays

#### Scenario: Same result as voice
- **WHEN** one Guest moves Wingull to the PC box in the editor and another Guest with the same Progress logs `deposited` Wingull by voice
- **THEN** both Guests have the same Team and PC box

### Requirement: PC box in the editor
The "PC box" button SHALL list the Guest's PC box members in order, each with its name, level and a "Withdraw" button whose accessible name is "Withdraw " then the name and level; an empty PC box SHALL read "The PC box is empty." Withdraw SHALL write a `withdrawn` Event with that member's PC box slot, only while idle, with the confirm line and Undo of the other editor actions.

#### Scenario: View and withdraw
- **WHEN** the PC box holds Lotad 6, the Team has 2 members, and the Guest taps PC box then Withdraw Lotad Lv 6
- **THEN** `#team` ends with a "Lotad Lv 6" chip and the editor shows "Lotad level 6 joined the Team."

#### Scenario: Withdraw with a full Team
- **WHEN** the Team has 6 and the Guest taps Withdraw on a PC box member
- **THEN** the editor shows the refused line naming one Team member to deposit first, and nothing changes

#### Scenario: Empty PC box
- **WHEN** the PC box is empty and the Guest taps PC box
- **THEN** the editor reads "The PC box is empty."

### Requirement: PC box from the Team list
The open Team list SHALL end with a `#pc-box-open` button reading "PC box (N)", N the PC box size, that opens the editor's PC box view, so the PC box is reachable without editing a member (Abhishek, 2026-11-18: "I can't see the box"). The trainer card SHALL never list the PC box members, and the collapsed Team summary SHALL not change.

#### Scenario: PC box from the Team list
- **WHEN** the PC box holds Lotad 6 and Ralts 5 and the Guest opens the Team summary
- **THEN** `#pc-box-open` reads "PC box (2)" and tapping it opens the editor on the PC box list
- **AND** Close focuses `#pc-box-open` again

### Requirement: Editor is accessible and steady
Every editor control SHALL be a real button or labelled input at least 44px tall; opening the editor SHALL move focus into it. The editor SHALL use only `--maya-*` tokens in both themes, have no transition or animation under reduced motion, and open as an overlay that does not change the height of `#trainer-card` or `#talk-button`. It SHALL work with the Team summary collapsed or open, and `assets/js/talk_hook.js` SHALL have no diff.

#### Scenario: Targets and labels
- **WHEN** the editor is open at 375x667 in either theme
- **THEN** every button and the level input in `#team-editor` have a computed height of at least 44px and an accessible name
- **AND** the document scroll width is not larger than 375px

#### Scenario: Steady band
- **WHEN** the editor opens and closes at 375x667
- **THEN** `#trainer-card` and `#talk-button` have the same computed heights as with no editor

#### Scenario: Both themes on tokens
- **WHEN** the editor renders with `data-theme="light"` and with `data-theme="dark"`
- **THEN** its colours come only from `--maya-*` tokens and the colour gate test passes
- **AND** under `prefers-reduced-motion: reduce` nothing in `#team-editor` has a transition duration above 0 or an animation

#### Scenario: With the Team summary
- **WHEN** the Team summary is open and the Guest edits a member
- **THEN** the summary stays open and its names follow the new Team

### Requirement: Pending Question with countdown
After STT returns a non-empty transcript, the Talk screen SHALL show it in a pending Guest bubble `#pending-question` with its text in `#edit-input` and a countdown `#pending-countdown` with the hint "Tap to edit" and the seconds as text. The countdown animation SHALL NOT move under reduced motion. When it ends untouched the bubble stays as the asked Question until the Answer shows as a turn.

#### Scenario: Countdown shown
- **WHEN** STT returns "where do I catch Ralts?" and the countdown is 2000 ms
- **THEN** `#pending-question` shows "where do I catch Ralts?" and `#pending-countdown` contains "2"
- **AND** after the Answer the conversation shows a `.turn` with that Question and `#pending-question` is gone

#### Scenario: Reduced motion
- **WHEN** the Guest prefers reduced motion
- **THEN** `#pending-countdown` has no running animation and still shows the seconds as text

### Requirement: Tap to edit
`#edit-input` SHALL be a text field, so a tap focuses it in the same gesture and the phone keyboard opens. Focusing it during the countdown SHALL stop the countdown and show `#edit-send` and `#edit-cancel` in `#edit-form`, each at least 44 by 44 CSS px. Send SHALL send the edited text, trimmed, as a new Question; Cancel SHALL discard it. Empty text or text over 300 characters SHALL NOT be sent.

#### Scenario: Edit and send
- **WHEN** STT returns "where do I catch rawls", the Guest taps the text, changes it to "where do I catch Ralts?" and taps `#edit-send`
- **THEN** the countdown stopped on the tap, the agent is asked "where do I catch Ralts?" and the stored turn has that Question

#### Scenario: Cancel
- **WHEN** the Guest taps the text and then `#edit-cancel`
- **THEN** `#pending-question` is gone, the Talk button is `idle`, no Answer is spoken and no turn is stored

#### Scenario: Empty edit is not sent
- **WHEN** the Guest clears `#edit-input` and taps `#edit-send`
- **THEN** no new Question is sent and `#edit-form` stays open

#### Scenario: Targets are large enough
- **WHEN** the Question is open to edit
- **THEN** `#edit-send` and `#edit-cancel` each measure at least 44 by 44 CSS px

### Requirement: Hold again discards the pending Question
A hold on the Talk button while a Question is in its countdown or being edited SHALL discard it (its Answer never spoken, no turn stored) and record a new Question. A hold while Maya speaks SHALL stay a barge-in.

#### Scenario: Hold during the countdown
- **WHEN** a Question is pending and the Guest holds the Talk button and asks "is Zigzagoon on route 101"
- **THEN** the first Question's Answer is never spoken and the next pending bubble shows the new transcript

### Requirement: Type instead of speaking
A keyboard button `#type-button` (accessible name "Type a Question", at least 44 by 44 CSS px) next to the Talk button SHALL focus `#type-input` in `#type-form` in the same tap, with `#type-send` and `#type-cancel`. Send SHALL send the trimmed text to the agent with no STT and no countdown; Cancel SHALL close the form. Empty text or over 300 characters SHALL NOT be sent. A typed Question while Maya speaks SHALL cut her Answer.

#### Scenario: Typed Question answered
- **WHEN** the Guest taps `#type-button`, types "How do I earn Roxanne's badge?" and taps `#type-send`
- **THEN** the agent is asked "How do I earn Roxanne's badge?", the Answer is spoken, and the conversation shows that Question as the Guest's turn

#### Scenario: Typed Question too long
- **WHEN** the Guest sends 301 characters from `#type-input`
- **THEN** the agent is not called
