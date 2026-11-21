# Changelog

All notable changes to Maya are listed here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Commits follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

PRs add a fragment in `changelog.d/` (see its README) instead of editing this file; `release-manager` folds fragments in at release time.

## [Unreleased]

## [0.5.0] - 2026-11-21

### Added
- OpenSpec change `type-matchup` proposes a `type_matchup` read tool (what is good against a type, Pokémon or gym ace, and why) with hand-written reason lines checked at import (#206)
- OpenSpec change `longer-memory` proposes 25 turns of agent context with OpenRouter prompt caching and a per-turn log line (#206)
- `mix maya.fetch_access` regenerates `priv/data/access.json` from a walk over each listed map's layout at the pinned pokeemerald commit (one-way ledges, Cut trees, Surf on and off), and `mix maya.fetch_data` runs it last (#204)
- team_check tells whether your Team is ready for the Next gym, with each member's level gap and best type matchup against the ace (#201)
- `/talk?audio_debug=1` can pick the audio session while Maya speaks (`play-and-record`, `ambient`, `playback`) and close the mic right after the release, and shows whether the mic is open, to test whether Spotify keeps playing (#200)
- find_trainer tells who battles you on a place up to Mauville City, with each trainer's first party only (#198)
- find_item tells where to get an item inside the Spoiler horizon (ball, hidden, mart or gift), with marts and gyms through Mauville City and hand-listed HM and key item gifts confirmed in pokeemerald (#198)
- `factory:release` skill: after each retro batch (or on request) it says whether a release is due, proposes the version and a theme for Abhishek to name, hands off to `release-manager`, and can split unreleased changes into several releases (#196)

### Changed
- Factory improve run 8 over #187 to #204: E4 stays running, and the batch's lessons are folded into docs/factory/LESSONS.md (spoiler findings fix before merge, claims backed by their own confirmed write, generator scripts committed with their data, scripts for Abhishek run on macOS bash 3.2) (#207)
- Factory estimates are T-shirt sizes (XS, S, M, L, XL) instead of 30m, 1h, 2h; the cut comes past 2x the size's upper bound (XS 1h, S 2h, M 4h, L 8h), XL is never filed or started, and retro rows gain a `size` column with `estimate_h` as the size midpoint (#199)

### Fixed
- Petalburg Woods' X Attack now waits for Cut (1 badge), and the Route 104 PP Up and a Route 109 hidden Heart Scale wait for Surf (5 badges) (#204)
- A refused Humor or Event change no longer lets Maya claim it happened; she says the refusal instead (#203)
- A tool that cannot reach the database during a turn makes Maya say "I can't reach my notes right now, ask again soon?" instead of losing her train of thought (#203)
- Opening `/talk` while the database is down shows "Maya can't reach her notes right now. Try again in a minute." instead of an error page (#203)
- find_trainer gives the rival once, with the party for your starter, instead of six parties (#201)
- find_item and find_trainer no longer point to items or trainers you can only reach with Surf, Cut or from a later route (#201)

## [0.4.0] - 2026-11-19

### Added
- "Maya, humor 60": `set_setting` changes the Humor dial by voice (0 to 100) and says "Humor set to 60 percent."; spoilers and other Dials, or a value out of range, are refused (#190)
- The PC box on the Talk screen: a "PC box (N)" button under the open Team lists the PC box with a Withdraw button each, the same `withdrawn` Event as voice, with Undo and the full Team line (team-edit part D) (#182)
- `?audio_debug=1` on the Talk screen shows the audio session type and AudioContext state, with a picker for the after-turn session type (music resume spike) (#181)
- Tap a Team chip on the Talk screen to open a small editor: save a level, set as lead, move to the PC box or remove, with Undo; it writes the same Events as voice and only opens while idle (#178)
- Maya changes the Team by voice: put a Pokémon in the PC, take one out, pick a lead, say the whole Team, or correct a level up or down (#177)
- The Talk screen Team folds into one line ("Mudkip, Poochyena, Wingull +3", or "No Team yet"); a tap opens the full chips and the open list stays open through live updates (#176)
- Team changes as Events: `deposited`, `withdrawn`, `set_lead`, `set_team` and `set_level`, each one undoable Event, with a `slot` detail to pick one of two same-species members (team-voice part A) (#174)
- A Team change that changes nothing writes no Event, and a repeated deposit or withdraw inside 2 minutes is logged once (#174)

### Changed
- After a write, the rest of the turn uses a system prompt built from the new Progress (#190)
- The honesty check catches a "set to" or Dial change claim when no `log_event` or `set_setting` ran (#190)
- Factory improve run 7 over #172 to #185: E4 stays running (4 guarded follow-ups with known escaped defects: #130, #145, #176, #178), no new experiment; strict OpenSpec validation in CI and real-model checks of risky integration tasks listed as candidates (#189)
- Factory lessons from #172 to #185 folded into `docs/factory/LESSONS.md` (39 rules) (#189)
- Documented that iOS does not resume other apps' audio after Maya's turn (web limit, tested on the phone); a native wrapper is in PHASE_2.md (#185)
- `set_team` is only for the whole Team; "Lotad level 14." is set_level, so unnamed members stay on the Team (#184)
- Spoken Answers are trimmed to 3 sentences, and the prompt tells Maya never to mention tools and to state corrections plainly (#179)
- Team chips are 44px buttons (#178)
- The log_event tool offers set_level instead of level_up, and Maya never says a Team change happened unless log_event confirmed it (#177)
- Factory improve run 6 over #138 to #166: E4 stays running (1 of 5 guarded follow-ups known; phone checks on #135, #136, #145 and #150 close it), no new experiment, review precision candidate listed (#172)
- Factory lessons from #138 to #166 folded into `docs/factory/LESSONS.md` (39 rules) (#172)

### Fixed
- A database outage during a turn no longer shows "voice is down": when Progress cannot be read Maya says "I can't reach my notes right now, ask again soon?" (#191)
- When storing a turn or its timings fails, Maya's Answer stays on screen and the Conversation keeps running instead of crashing (#191)
- The agent stage budget is 20 s (was 8 s), so a Team change with a corrective round no longer ends in "Lost my train of thought" (#186) (#187)
- A Team change that really ran is no longer rejected as an unbacked claim when Maya forgets to cite it ("Not sure I got that right") (#184)
- Ordinary Answers such as "Got it, Brawly uses Fighting types." pass the honesty check; everyday change words count only next to a Progress noun (#184)
- A write that ran is never silent: after two rejected replies, the round cap or an OpenRouter error, Maya says its confirm line instead of the fallback or "Lost my train of thought" (#184)
- Asking "What tools do you have?" no longer gets the fallback line (#184)
- A cited tool call id that never ran is ignored instead of costing a corrective round; write claims are still checked against the calls that ran (#184)
- Maya's spoken Answer on iPhone: the audio session is "playback" while she talks with the mic closed (silent switch), every press, release and chunk wakes a suspended or interrupted AudioContext, a playback clock frozen for 2.5 s shows "voice is down" instead of silence, a hidden page cuts the turn, and a cut turn's late audio is dropped by turn id (#181)
- A failed TTS request logs the first 500 bytes of the provider's error body, with the Answer text redacted (#181)
- Undo right after "Set as lead" no longer loses the member, and unknown Team editor params no longer crash the Talk screen (#178 review) (#180)
- Maya only claims tool results she received: every Answer is structured `{answer, used_tool_calls}` (OpenRouter structured output with `require_parameters`, checked by `Maya.Agent.Answer`), and a cited call that did not run, a write claim without `log_event`, or talk about tools gets one corrective request, then "Not sure I got that right, ask me again?" (#179)
- The talk-screen spec passes strict validation again (Hold end split into Hold end and Hold end report) (#175)

## [0.3.0] - 2026-11-16

### Added
- OpenSpec changes `team-voice` (log_event kinds deposited, withdrawn, set_lead, set_team and set_level) and `team-edit` (a Team editor on the Talk screen trainer band with a PC box view, writing the same Events) (#166)
- `search_guide` tool: Maya answers "where now?" and "what is in this place?" from short original Walkthrough notes, filtered by the Spoiler horizon; past the horizon or unlisted places are `past_horizon` (#164)
- 21 Walkthrough notes and locations, Littleroot Town to Mauville City (Granite Cave first floor, Route 109 and Slateport City at 1 badge; Routes 107, 108, 110 and Mauville City at 2) (#164)
- The import fails closed on a note for an unlisted location, a lower badge tag or a name past the note's horizon (#164)
- Guide spoiler probes at 0, 1 and 2 badges in the spoiler gate (#164)
- `log_event` kind `released` removes one Pokémon from the Team (or the PC box), so an existing duplicate can be fixed (#162)
- OpenSpec change `team-collapse`: the Team in the Talk screen trainer band folds into one line of names ("Mudkip, Poochyena, Wingull +3"), collapsed by default, tap to open (#158)
- Self-hosted Fraunces italic font (`fraunces-latin-wght-italic.woff2`, SIL OFL 1.1) (#154)
- OpenSpec change `structured-answers` (#118): the final Answer is OpenRouter structured output checked in the loop, one corrective request, then an honest fallback line (#153)
- One shared header on `/`, `/talk` and `/factory`: the "Maya" wordmark in Fraunces, one link ("Talk", or "Home" on the Talk screen) and the theme toggle (#150)
- `factory:dashboard` project skill: one private page rebuilt from live sources each run (Needs Abhishek first, then flow, quality and the running experiment), every number with its source and read time; nothing is committed (#148)
- JS tests for the Talk hook's pure helpers (`node --test test/js/*_test.mjs`), run in CI's format job (#145)
- OpenSpec changes `tide-header` (one shared header with a Fraunces wordmark and a one-button theme toggle) and `tide-cohesion` (Talk screen without containers in the tide art band, homepage headline "Your Pokédex has a voice now.", #135 and #136 review fixes) (#140)
- OpenSpec change `tide-homepage`: the Tide homepage with a real turn, Meet Maya and the spoiler promise band (#131)
- OpenSpec change `tide-talk`: the Tide Talk screen with a slim header, unboxed turns and a 72px Talk pill (#131)
- Factory experiment E4: `factory:review` blocks a PR that touches the press path or Talk layout until its body has a `Phone check:` line from a real phone (#129)
- `move_learnset` tool: a Pokémon's Emerald level-up moves up to the level horizon (the Next gym ace's level, or the Team's highest level when higher), so Maya names moves from data only (#128)
- `priv/data/learnsets.json` from PokeAPI (`emerald` version group) and a `learnsets` table loaded by `mix maya.import` (#128)
- Three move probe cases in the Sunday goal spoiler gate (#128)

### Changed
- Slateport City and Route 109 need 1 badge in the gym 3 scope (guide-and-humor, trainers-items-readiness), since Mr. Briney sails there from Dewford before Brawly (#156)
- The Talk screen has no panel or card box: the trainer info sits in the tide art band like the homepage hero, and every Question is small and muted like the homepage real turn (#154)
- The homepage headline reads "Your Pokédex has a voice now." in the real Fraunces italic, and more of the tide art shows above it (#154)
- The `guide-and-humor` and `trainers-items-readiness` OpenSpec changes now reach gym 3 (Mauville City): seven more locations, 21 Walkthrough notes, marts, gyms and gifts to Mauville, probes at 1 and 2 badges, each change split into two build PRs (#152)
- Parked the shared login (#49) in PHASE_2.md; guests use Maya without a login for now (#151)
- The theme toggle is one 44px icon button (a moon by day, a sun at night); the first visit follows the phone and a tap is remembered, with no "system" option (#150)
- Factory retros run in batches once 10 merged PRs have no metrics row, instead of after each merge; `factory:improve` runs right after each batch (#144)
- Factory improve run 5 over #127 to #136: E4 stays running (4 of 5 follow-up retros, the phone checks on #135 and #136 still open), no new experiment (#142)
- Factory lessons from #127 to #136 folded into `docs/factory/LESSONS.md` (39 rules) (#142)
- The homepage is the Tide layout: a full bleed tide backdrop (night backdrop at night) fading into the page, the headline "Ask out loud. No spoilers.", an "Open Talk" header link, a real turn at Route 104 with the median Answer time, "Meet Maya" with her read-only Dials and three things she says, the voice loop as ruled numbered lines and a sea band for the spoiler promise (#136)
- Talk screen in the Tide look: a slim header of one height over faint tide art (night art at night), an unboxed chat with hairlines and a 25px latest Answer, and a 72px Talk pill; no behaviour change (#135)
- The Talk screen, homepage and `/factory` follow the theme on the design tokens: Calm Emerald by day, Emerald night at night (deep night sea, gold hairline on the trainer card, the ball glows); Fraunces for headings and the gym line, Inter for Answers and labels (#130)
- The footer art, `theme-color` metas (`#0f5a3a` light, `#08181a` dark), manifest colours, `maya-icon.svg`, `logo.svg`, README `hero.svg` and `footer.svg` use only palette values; favicon, app icons and `og-image.png` re-rendered from them (#130)
- The colour gate allow list is empty: no colour literal is left outside the token layer (#130)
- Factory experiment E3 closed as inconclusive: its text Question could not catch the phone-only bugs it was scored on; `POST /health/ask`, the hourly Question and the nightly spoiler probe stay (#129)
- Factory lessons from #63 to #124 folded into `docs/factory/LESSONS.md` (36 rules) (#129)

### Fixed
- The Talk button no longer stays stuck in Listening when pointer capture is lost and the finger lifts off the button; the pressing finger's lift or cancel ends the hold once wherever it lands (#165)
- With realtime on and batch as the final source, release now sends `input_audio.end` to the realtime session and keeps it open while batch runs, so the last words show in the live preview before the final transcript replaces it (#163)
- A catch the agent logs again within 2 minutes (same species and level) is written once, so the Team no longer fills with duplicates (#162)
- A catch with a full Team goes to the PC box with a "sent to the PC" confirm instead of being refused (#162)
- The Talk page now connects when the browser blocks storage (some private modes and in-app browsers); LiveView keeps its small notes in memory for the page instead (#161)
- The trainer card on the Talk screen updates as soon as Maya logs or undoes an Event (badge count, Next gym, Team), with no reload (#160)
- The day and night theme and the toggle now work when the browser blocks storage (some private modes and in-app browsers): the theme follows the phone and a tap holds for the page (#155)
- With JavaScript off on a dark phone the theme toggle shows the sun, matching the night colours (#155)
- `factory:dashboard` keeps Question and Answer text from a failed smoke run off the page, counts only feature branches as running builders, and treats skipped or neutral checks as green (#149)
- Music or video another app was playing can resume after a turn with Maya: once the mic closes and Maya is silent, the Talk hook suspends its AudioContext and sets the audio session back to "auto" (#145)
- Conversation and Talk screen tests wait up to 1 s for each turn message instead of 100 ms, so a slow CI runner no longer fails main and skips the Codecov upload (#138)
- The sticky trainer card stays compact and opaque with a full Team (chips wrap across the card) (#117) (#130)
- The "Yes, start fresh" button text reaches 4.5:1 by day (`btn-error`, was `btn-warning` at 4.29:1); the theme toggle buttons are 44 px targets (#130)

### Removed
- Dead demo slot and catchphrase CSS; the promise band rules are scoped to the homepage (#154)
- The homepage demo slot, its screenshots in `priv/static/images/demo/` and the planned demo clip slot (#136)

## [0.2.0] - 2026-11-15

### Added
- Design tokens for Calm Emerald (day) and Emerald night in `assets/css/app.css`: colour, type, radius, shadow and motion, with daisyUI themes on the tokens (primary is emerald, no Phoenix purple) (#124)
- Self-hosted Fraunces (headings) and Inter (body) woff2 files with their SIL OFL 1.1 licences; one Inter preload (#124)
- `docs/design-system.md` and tests for token coverage, contrast pairs, the font route and a colour gate that fails on colour literals outside the token layer (#124)
- Spoiler gate CI job (`spoiler-gate`, inside `ci-success`): 20 spoiler probes and an honesty case run through the agent with the model stubbed (#123)
- Nightly spoiler probe workflow that asks production the 20 probe Questions and opens a `bug` Issue on a leak (#123)
- `mix maya.sunday` prints the Sunday goal phone checklist and the latency SQL (#123)
- OpenSpec change `move-learnset`: `move_learnset(species)` gives Emerald level-up moves up to the Next gym ace's level, from PokeAPI learnsets (#122)
- OpenSpec change `guide-and-humor`: `search_guide(location)` with Walkthrough notes Littleroot to Dewford, and `set_setting(humor)` by voice (#122)
- OpenSpec change `trainers-items-readiness`: `find_trainer(place)`, `find_item(name)` and `team_check()` inside the Spoiler horizon (#122)
- OpenSpec change `sunday-goal`: a 20-question spoiler probe set as data, a no-network `spoiler-gate` CI job in `ci-success`, a nightly real-model spoiler probe that opens a `bug` Issue on a leak, a stubbed Roxanne then Ralts test, an honesty case from #118 and `mix maya.sunday` for the Sunday goal phone checklist (#119)
- OpenSpec change `design-tokens`: Maya design system tokens (Calm Emerald by day, Emerald night), self-hosted Fraunces and Inter, daisyUI on the tokens, a colour gate and docs/design-system.md (#112)
- OpenSpec change `design-apply`: the design system on the Talk screen, homepage, /factory, icons, og-image and README art (#112)
- `factory:ask` intake skill that routes every request to one route (Bug, Feature, Later, Experiment, Question, Gated, Ambiguous), creates at most one thing and records the date and Abhishek's words (#111)
- A Candidates list in docs/factory/experiments.md that `factory:improve` prefers when it opens an experiment (#111)
- Voxtral realtime STT relay (`mint_web_socket` 1.0.6) with live words in the Guest's bubble while held, off unless `MAYA_STT_REALTIME=true`; batch STT stays the final source and the fallback (ADR-009) (#109)
- `turns.stt_source` and `mix maya.stt_eval` (realtime spike, Voxtral TTS eval clips, WER and name accuracy for batch and realtime) (#109)
- OpenSpec change `tshirt-sizes`: factory estimates move from hours to T-shirt sizes XS, S, M, L, XL (#108)
- OpenSpec change `factory-ask`: one `factory:ask` entry point routes each request to a bug Issue, `factory:plan`, a PHASE_2.md line, an experiment candidate, an answer, or a stack question for Abhishek (#106)
- Public `/factory` page on the agent-run software factory: four stations, the gates that ignore prompts (spoiler gate planned), the flywheel with experiments E1 to E3 and the honest review reward backfill; indexable, every number tested against `docs/factory/experiments.md` (#103)
- "Review reward backfill" section in `docs/factory/experiments.md` (4 of 67 findings led to a tested fix, median precision 0.00, 2 of 3 escaped defects missed) (#103)
- Each hold logs whether the mic was already warm and the post-roll it recorded (#101)
- Public homepage at `/`: hero with the Emerald ball over the tide, two real Talk screen screenshots, the voice loop (latency pending the phone check), the spoiler promise and a footer; indexable by search engines (#100)
- OpenSpec change `warm-mic`: the mic stays warm through a turn with a 300 ms pre-roll so the first syllable is kept, and turns off about 5 s after the last turn (#99)
- OpenSpec change `transcript-edit`: the transcript waits in the Guest's bubble with a 2 s countdown, tap to edit or cancel, and a keyboard button to type a Question (#99)
- OpenSpec change `realtime-transcription`: Voxtral realtime STT over a server-side WebSocket with live words, an accuracy gate against batch on 20 test Questions, and batch fallback (#99)
- TTS lessons from cantastorie and habla-hermano in docs/factory-learnings.md; "talk slower" idea in PHASE_2.md (#98)
- OpenSpec change `homepage`: a public homepage at `/` (hero, demo, voice loop, spoiler promise, footer) and the Talk screen at `/talk` behind the friends login (#90)
- OpenSpec change `factory-page`: a public `/factory` page on the agent-run software factory with numbers from the repo (#90)
- Maya can be added to a phone home screen as a full screen app (web app manifest, Apple home screen tags, Emerald theme colour) (#88)
- An original Emerald ball icon and favicon replace Phoenix's default; link previews show a 1200 x 630 card made from the README hero (#88)
- Maya stays out of search engines (robots meta and robots.txt) until the login lands (#49) (#88)
- Events: the `log_event` tool records a badge earned, a catch, an evolution, a level up or a move the Guest tells Maya about, updates their Progress in the same transaction and answers with a confirm line ("Stone Badge logged. Mudkip would approve.") (#86)
- "No" or "undo that" right after an Event restores the Progress from before it (#86)
- Validation from Maya's own data: only the Next gym's badge (a later or unknown gym gets one refusal that names only the Next gym), species in game data, levels 1 to 100, a Team of at most 6, places inside the Spoiler horizon (#86)
- Route 116, Rusturf Tunnel, Route 105, Route 106 and Dewford Town in `locations` (badge 1); everything past Dewford stays unlisted (#86)
- Each hold logs how it ended (`pointerup` or `pointercancel`), how long it was and how long the mic took to open, with no audio or text (#81)
- Trainer card on the Talk screen (layout B3): Maya's ball with a state ring, the Guest's location, the Next gym with its type chip, the Team with type dots and levels, and 8 badge slots with "N of 8 badges", all from the Guest's Progress and never past the Next gym (#74)
- The Talk screen follows each moment: the card shrinks while the Guest talks and waits, the ring pulses coral, spins gold or glows green with a sound wave, and an aria-live status line says what is happening (no animation under reduced motion) (#74)
- `factory:review` lists every finding with an id (F1, F2, ...), severity and `file:line` in a parseable Findings table (#69)
- `factory:retro` scores each finding after merge (`acted_tested`, `acted_untested`, `dismissed`) and links escaped defects to a finding or a miss, with new columns `review_findings`, `findings_acted`, `review_precision` and `review_misses`; `factory:improve` scores the last two (#69)
- Guest sessions (ADR-008): every browser gets a random `guest_id` in the signed session cookie (kept for a year) and its own Conversation and Progress; a new Guest's Progress is seeded from `priv/progress.json` on first use (#65)
- "Start fresh" on the Talk screen, with an in-page confirm step, gives the browser a new Guest; the old rows stay in Postgres (#65)
- `POST /health/ask`, one text Question to the agent gated by the `SMOKE_TOKEN` header token (404 when unset); the hourly post-deploy smoke check asks it and opens a `bug` Issue on a failed or empty Answer (factory experiment E3) (#63)
- `escaped_defects` column in `factory:retro` and `factory:improve` (#63)
- Maya answers Questions with a hand-written agent loop over OpenRouter tool calling (at most 4 rounds, malformed tool arguments handled), using the last 5 turns as context (#55)
- `gym_counter` and `find_pokemon` tools that return Facts from Maya's own data inside the Spoiler horizon, or not found, or past the horizon (#55)
- System prompt with the Answer rules (Facts only from tools, no spoilers, "Not sure", 2 to 3 sentences, Dials, Catchphrase, inclusive language) (#55)
- `turns.agent_ms` and the agent stage in `mix maya.latency`; `mix maya.compare_models` and ADR-007 (Proposed) for the agent model choice (#55)
- README hero (`docs/assets/hero.svg`) and footer (`docs/assets/footer.svg`), hand-written SVGs with Maya's motifs (#54)
- Tests for the core components and `mix maya.import`; the coverage floor rises from 67 to 89 percent (#53)
- `mix test --cover` writes `cover/lcov.info` and CI uploads it to Codecov (never fails CI); Codecov badge in README.md (#53)
- `/` is the Talk screen: hold the Talk button to ask, release to send one Question, and Maya speaks it back (echo until the agent lands) as streamed Voxtral PCM over the LiveView socket (#48)
- Barge-in (a hold while Maya speaks stops the audio and keeps the cut Answer as text) and a "voice is down" note when STT or TTS fails (#48)
- `turns` table with per-stage milliseconds (mic release, STT, TTS first byte, playback start) and `mix maya.latency` for p50 and p95 (#48)
- `scripts/voice_spike.sh` to check which recording formats Voxtral STT accepts and the TTS PCM format (#48)
- `mix maya.fetch_data` writes pokeemerald (pinned commit) and PokeAPI Generation III data to committed `priv/data/`, and `mix maya.import` (or `Maya.Release.import_data/0`) loads species, type matchups, encounters, trainers, locations and the Progress seed into Postgres with no network (#47)
- Spoiler horizon as pure functions (`Maya.Horizon.next_gym/1`, `badges_earned/1`, `allowed?/2`), failing closed for any location not in the hand-written Littleroot Town to Rustboro City table (#47)
- Docs/elixir-phoenix-in-5-minutes.md, Elixir and Phoenix explained through Maya's own code (after habla-hermano's FastAPI and LangGraph explainer), linked from ARCHITECTURE.md (#46)
- Two PHASE_2.md ideas: a `factory:idea` intake skill, and privacy at or above habla-hermano (#42)
- ARCHITECTURE.md from the F3 design session (why Elixir, Phoenix and functional programming, voice loop, processes, agent tools, data, build order), ADR-005 (voice transport over the LiveView socket) and ADR-006 (Progress and the Conversation live in Postgres) (#35)
- Rotating Poké facts on the home page: 12 spoiler-free facts from before the first gym, each checked against pret/pokeemerald or PokeAPI, rotated with CSS only (no JavaScript), static under reduced motion and fully readable by screen readers (#33)

### Changed
- Reduced motion turns every animation off through `--maya-duration`; the night `theme-color` is the night background `#08181a` (#124)
- The Talk button streams the held Question as 200 ms PCM chunks over the LiveView socket instead of one upload on release; the final Question shows as soon as it is transcribed (#109)
- The site footer links Home (`/`) (#103)
- Homepage tests select by DOM instead of matching raw HTML, and the homepage Talk link uses a verified route (review follow-up to #100) (#102)
- The mic now closes 4 s after the button is back to idle, and at once when the page is hidden, so the phone's mic indicator goes off soon after the last turn (#101)
- The Talk screen moves from `/` to `/talk` (public, `noindex`; login deferred, see #49); Start fresh returns to `/talk`; the home screen app opens `/talk` (#100)
- `robots.txt` disallows only `/talk` and `/fresh`; the post-deploy smoke check checks `/`, `/talk` and `/health` (#100)
- The trainer card on the Talk screen is sticky, so the HUD stays visible while the chat scrolls (#84)
- The chat shows the last 3 exchanges (the Guest right, Maya left, the latest Answer largest, older ones faded) and "(nothing heard)" as a friendly line (#74)
- The Talk button is pinned in the thumb zone above the safe area, with a mic icon, one label per moment ("Hold to talk", "Release to send", "One sec…", "Hold to cut in") and a hint line (#74)
- "Pokémon" is written with the accent in all user-facing text and docs (code identifiers stay ASCII); the README hero now carries the "Maps, Answers, Yaps, Advice." tagline and the Mudkip line that missed #54 (#71)
- A Conversation stops after 30 idle minutes and reloads its turns from Postgres on the next visit or Question (#65)
- The release import seeds game data only; existing turns and Progress belong to the Guest `legacy` (#65)
- Factory experiment E2 (Hex mirror fallback) kept; LESSONS.md gains the lessons from #52 to #60 (#63)
- The Answer is no longer an echo; an agent failure speaks "Lost my train of thought, ask again?" (#55)
- `OPENROUTER_API_KEY` is read in `config/runtime.exs` and listed in `render.yaml` (#55)
- Coverage floor raised from 89 to 90 percent (measured 90.97) (#55)
- README.md rewritten in the habla-hermano shape: pitch, how it works, how we know it works, decisions and trade-offs (ADR-001 to ADR-006), run it locally, built with, the factory and a docs table (#54)
- Factory experiment E1 kept (first-pass green 60% to 80%); experiment E2: CI setup falls back to the cdn.jsdelivr.net hex mirror; seven retro lessons folded into docs/factory/LESSONS.md (#52)
- `MISTRAL_API_KEY` is read in `config/runtime.exs` and listed in `render.yaml`; without it the app shows Answers as text (#48)
- Inclusive language: earn badges, battle, get past a gym; never "beat" or "defeat" (PRODUCT.md, GLOSSARY.md, ARCHITECTURE.md, factory:recap) (#44)
- Factory experiment E1: `factory:build` step 9 merges main and finishes everything before the first push, then waits for the first CI run; first factory:improve run folds five retro lessons into docs/factory/LESSONS.md (#36)

### Fixed
- `find_pokemon` no longer returns types for a gift, legendary or fossil Pokémon with no wild place inside the horizon (Groudon, Beldum) (#123)
- The first word of a Question is no longer cut off: the mic stays warm through a turn and keeps the 300 ms before each press (#101)
- The last word of a Question is kept: the mic records 150 ms after release while the button already shows it sent (#101)
- Holding the Talk button on iPhone no longer ends early: the trainer card stays full while recording, and server re-renders no longer reset the button's state mid-hold (#81)
- The microphone is released when each hold ends, so the phone's mic indicator goes off between Questions (#81)
- Speech to text hears Pokémon, place and gym names: each request sends the known names as `context_bias`, with the Guest's Team, Next gym leader and horizon locations first (#80)
- A near-miss name in the transcript ("rawls", "torch ick") is corrected to the known name before Maya answers; English words stay as spoken (#80)
- The production probe asks as the smoke Guest, so main compiles again after #63 and #65 (semantic merge conflict); its question uses inclusive wording (#73)
- Every deploy imports game data and seeds Progress (only when missing) in the pre-deploy migrate, so production Answers stop being "Lost my train of thought" (#60)
- The agent returns {:error, :no_progress} instead of crashing when Progress is empty (#60)
- Agent, STT and TTS failures and crashed turn Tasks log their reason with Logger.warning (never transcripts, Answers or keys) (#60)
- Speech to text pins the language to English (`stt_language: "en"`), so Questions no longer come back as Hindi or garbled names (#59)

### Removed
- The old hero, the second "Maya" heading, the tagline and the Mudkip hype line from the Talk screen (#74)
- Unused generator code: `Maya.Mailer`, Swoosh and DNSCluster (#53)

## [0.1.0] - 2026-11-14

### Added
- PRODUCT.md from the grill-with-docs session, GLOSSARY.md, and ADR-004 (facts only from tools and data) (#27)
- Pokemon themed welcome page: Emerald edition CSS Poke Ball on a calm tide backdrop, Mudkip hype line, spoiler-free badge case with 8 empty slots; app header shows only the Maya wordmark and theme toggle; id-based landing-page tests; coverage floor raised to 38% (#24)
- Three Gemini-generated backdrop images (tide, dusk, night) in `priv/static/images/backdrops/`; the home page uses tide (#24)
- Factory flywheel: `factory:retro` (metrics row and one lesson per merged PR in `~/maya-factory/`), `factory:improve` (one measured experiment per 5 retros, kept or reverted), `factory:recap` (under 15 line digest); `docs/factory/LESSONS.md` and `docs/factory/experiments.md` (#25)
- Factory freeze rule: after #19, #20 and changelog fragments, factory changes are fixes only until Maya Block 1 ships; onboarding and coverage-88 move behind Block 1 (#23)
- CI/CD hardening: parallel format, credo, test (coverage floor 32%), security (mix_audit, sobelow) and docker boot jobs behind one `ci-success` check; strict Content-Security-Policy; `/health/version`; post-deploy smoke check that opens a bug Issue (#22)
- `factory:pause`, `factory:resume` and `factory:cleanup` skills; `next-task` ranks `paused` Issues (#21)
- OpenSpec changes `ci-cd-hardening`, `factory-flywheel` (retro, improve, recap) and `pokemon-welcome-page`; `.claude/worktrees/` ignored (#17)
- Factory station skills `factory:plan`, `factory:build`, `factory:test`, `factory:review`: ordered, gated wrappers over the existing skills; "Skills by station" in FACTORY.md (#15)
- `quiz-me` skill: on-demand 5 question quiz on recent PRs, specs and ADRs, code structure and factory ops, with spaced repetition borrowed from coding-tutor (#14)
- OpenSpec change `hello-page-says-maya`: Maya landing page, the factory dry run (#12)
- OpenSpec 2.0 for the spec station: `openspec/` (config with Maya context and rules), six skills in `.agents/skills/` linked from `.claude/skills/`; ADR-003 (#11)
- Factory runtime without Herdr: Claude Code sessions, worktree builders, reviewer subagent, Remote Control for the phone; Herdr kept as an optional devex layer with its skill (`.claude/skills/herdr/`, Herdr 0.9.5) (#10)
- Permission deny rules for `mattpocock-skills:tdd` and `mattpocock-skills:diagnosing-bugs`, so Superpowers keeps TDD and debugging (#9)
- Matt Pocock skills setup: `docs/agents/` (GitHub tracker, default triage labels, single-context domain docs) and an Agent skills section in CLAUDE.md (#9)
- `.env.template` listing every env var, with the Supabase pooler URI format (#6)
- Render deploy: `render.yaml` (Frankfurt, `0.5c-512mb`, deploy after CI, migrations pre-deploy), release Dockerfile, `/health` route, `render-deploy` skill (#4)
- ADR-002: Postgres on Supabase (#4)
- ADR-001: agent-run software factory, why, what and how, with a Mermaid pipeline diagram and guardrails; "How it works" section in FACTORY.md (#3)
- Factory docs from sibling repos: `settled-architecture` and `next-task` skills, definition of done, ADR convention, PR template, `PHASE_2.md`, this changelog (#2)
- `.claude/settings.json` allowlist for mix, git read and `gh` commands, denying `gh pr merge`, force pushes, pushes to main and reading `.env` (#2)
- `release-manager` and `project-manager` project skills (#2)
- CI on GitHub Actions with a pgvector Postgres service: compile warnings as errors, format check, credo, tests (#1)
- Credo as a dev and test dependency (#1)
- `docker-compose.yml` for a local pgvector Postgres bound to localhost (#1)
- Phoenix 1.8.16 LiveView app scaffold, CLAUDE.md and FACTORY.md handoff docs

### Fixed
- Post-deploy smoke check runs every 15 minutes instead of on push, so it can no longer deadlock Render's checksPass deploys; it keeps one open bug Issue per commit and always exits 0 (#28)
- App refuses to boot when `SECRET_KEY_BASE` is under 64 bytes, so a bad key fails the deploy instead of serving 500s (#8)

### Changed
- Welcome page hero shows more of the sea: the frosted panel sits at the top, smaller and more transparent, above a band of open waves (#30)
- Voice outage shows Answers as text; the browser Web Speech fallback moved to PHASE_2.md (#27)
- `factory:build` reads `docs/factory/LESSONS.md` at step 4 and runs `factory:retro` at step 11; the daily digest is `factory:recap` (#25)
- Changelog entries are per-PR fragments in `changelog.d/`, folded into CHANGELOG.md by release-manager, so PRs no longer conflict on the changelog (#23)
- Home page is a minimal Maya landing page (heading, tagline, title "Maya"); generator content removed. Factory dry run; spec `openspec/specs/landing-page/` (#16)
- Plan station: one OpenSpec change and one GitHub Issue per block; builders archive the change in their PR. Matt `to-spec` and `to-tickets` retired (#11)
- Telegram bot and watcher (F4) moved to PHASE_2.md (#10)
- Superpowers SessionStart hook kept in every pane, planner included; intake invokes `grill-with-docs` explicitly (#10)
- Skill names updated to the current Matt Pocock set: `to-spec` and `to-tickets` replace `to-prd` and `to-issues` (#9)
- Supabase project recorded as Ireland (eu-west-1); `DATABASE_URL` pitfalls (API URL, direct host, port 6543) and a local connection test documented (#7)
- Supabase CA certificate shipped in `priv/certs/` instead of the `DATABASE_CA_CERT` env var (#5)
- Prod database connects to Supabase with verified SSL; LiveView host falls back to `RENDER_EXTERNAL_HOSTNAME` (#4)
- Project name written as "Maya", never all caps, across docs and skills (#2)

[Unreleased]: https://github.com/darth-dodo/maya/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/darth-dodo/maya/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/darth-dodo/maya/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/darth-dodo/maya/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/darth-dodo/maya/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/darth-dodo/maya/releases/tag/v0.1.0
