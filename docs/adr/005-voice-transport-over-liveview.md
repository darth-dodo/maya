# 005: Voice transport over the LiveView socket

- Status: Accepted (the "In" bullet superseded by [009](009-realtime-transcription.md): Questions now stream in as chunks, not an upload)
- Date: 2026-11-14

## Context
Answer time must be p50 at most 5 s and p95 at most 8 s. The browser needs the mic (HTTPS) and must play speech fast. Calling Mistral from the browser would expose the API key and need CSP changes. Waiting for a whole audio file before playing adds the full TTS time to every Answer.

## Decision
- **In:** the hook records one Question and sends it as a LiveView upload (`auto_upload`, `chunk_size` 256 KB, 1 MB cap). The server calls Voxtral STT and drops the clip.
- **Out:** the server calls Voxtral TTS with `stream: true` and `pcm`, and relays chunks over the LiveView socket; the hook plays them with Web Audio as they arrive.
- **Format:** a spike first checks MP4/AAC (iOS) and WebM/Opus (Chrome) against Voxtral, which does not document its containers. If either fails, record 16 kHz mono WAV in the browser. No server transcoding.

## Consequences
- Easier: one connection, no CSP change, keys stay on the server, first sound before TTS finishes, barge-in is a local stop plus a cancel message.
- Harder: PCM playback code in the hook (sample rate must match TTS output); a long Answer streams through the Conversation process.
- Check: the Block 2 spike results and per-stage timings; revisit if the socket relay shows up in the TTS first byte to playback start gap.
