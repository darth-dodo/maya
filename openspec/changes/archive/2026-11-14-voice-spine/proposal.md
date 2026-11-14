# Proposal

GitHub Issue: #38

## Why

Voice is the experience (CLAUDE.md). Before the agent exists (#39), the push-to-talk loop must work end to end on its own: a held Talk button becomes a Question, Maya speaks it back as streamed PCM, every stage is timed, barge-in works and a voice outage degrades to text. Building the spine first lets Block 3 measure only the agent stage.

## What Changes

- `/` becomes the Talk screen (a LiveView): the Talk button, the Conversation list, and the Emerald ball, tide hero, tagline and Mudkip hype shrunk into a top panel. The badge case and Poke facts show only while the Conversation is empty.
- The Talk button runs a browser state machine (`idle, recording, uploading, waiting, speaking`). One hold records one Question, sent as one LiveView upload (ADR-005).
- One Conversation process, supervised and found by name, owns the turn in flight: STT, then the Answer (an echo of the transcript in this block), then streamed TTS relayed as PCM over the LiveView socket and played with Web Audio.
- Barge-in: a hold while Maya speaks stops audio at once and cancels the TTS stream; the cut Answer stays as text.
- Voice outage: an STT or TTS error shows the Answer as text with a "voice is down" note.
- Every turn is a `turns` row (Question text, Answer text, cut flag, per-stage milliseconds, ADR-006). `mix maya.latency` prints p50 and p95 per stage.
- Config: STT and TTS model names, voice, sample rate and per-stage timeouts in config; `MISTRAL_API_KEY` read only in `config/runtime.exs`, listed in `render.yaml`, `.env.template` and the FACTORY.md secrets table.
- Format spike (ADR-005): `scripts/voice_spike.sh` sends WAV, MP4/AAC and WebM/Opus clips to Voxtral STT and probes the TTS PCM format. Results go in `design.md`. Until it runs with a key, the hook records 16 kHz mono WAV, which needs no container support.

Out of scope: the agent and its tools (#39), Events, Dials, Web Speech fallback, server transcoding. New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities
- `voice-loop`: Question in, spoken echo out, barge-in, voice outage, per-stage timing and the latency report.
- `talk-screen`: the Talk screen at `/` and the Talk button behaviour.

### Modified Capabilities
- `landing-page`: the badge case and Poke facts show only while the Conversation is empty.

## Impact

- New: `lib/maya/conversation.ex`, `lib/maya/voice/*.ex`, `lib/maya_web/live/talk_live.ex`, `lib/mix/tasks/maya.latency.ex`, `assets/js/talk_hook.js`, a `turns` migration, `scripts/voice_spike.sh`, tests.
- Changed: `lib/maya/application.ex` (Registry, DynamicSupervisor, Task.Supervisor, timing handler), router (`/` is live), `config/*.exs`, `render.yaml`, `.env.template`, `FACTORY.md`, `assets/js/app.js`, `assets/css/app.css`.
- Removed: `PageController` home page (replaced by the Talk screen).
- No new dependencies; the CSP is unchanged.
