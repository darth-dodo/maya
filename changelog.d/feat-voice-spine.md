Added: `/` is the Talk screen: hold the Talk button to ask, release to send one Question, and Maya speaks it back (echo until the agent lands) as streamed Voxtral PCM over the LiveView socket
Added: Barge-in (a hold while Maya speaks stops the audio and keeps the cut Answer as text) and a "voice is down" note when STT or TTS fails
Added: `turns` table with per-stage milliseconds (mic release, STT, TTS first byte, playback start) and `mix maya.latency` for p50 and p95
Added: `scripts/voice_spike.sh` to check which recording formats Voxtral STT accepts and the TTS PCM format
Changed: `MISTRAL_API_KEY` is read in `config/runtime.exs` and listed in `render.yaml`; without it the app shows Answers as text
