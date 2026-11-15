# Spec Delta

## MODIFIED Requirements

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

## ADDED Requirements

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
