#!/usr/bin/env bash
# Voice format spike (ADR-005, openspec change voice-spine design.md).
# Sends one spoken clip as WAV, MP4/AAC and WebM/Opus to Voxtral STT, then probes the TTS PCM format.
# Usage: MISTRAL_API_KEY=... scripts/voice_spike.sh      (DRY_RUN=1 makes the clips and prints the calls only)
# Needs macOS `say` and `afconvert`; WebM/Opus needs ffmpeg (skipped if missing). Never prints the key.
set -euo pipefail

STT_MODEL="${STT_MODEL:-voxtral-mini-transcribe-3}"
TTS_MODEL="${TTS_MODEL:-voxtral-mini-tts-3-0}"
TTS_VOICE="${TTS_VOICE:-01a135c4-d896-70d9-a498-2db10c5915ff}"
API="https://api.mistral.ai/v1/audio"
OUT="${OUT:-$(mktemp -d)}"
DRY_RUN="${DRY_RUN:-}"

if [ -z "$DRY_RUN" ] && [ -z "${MISTRAL_API_KEY:-}" ]; then
  echo "MISTRAL_API_KEY is not set (or run with DRY_RUN=1)" >&2
  exit 1
fi

echo "clips in $OUT"
say -o "$OUT/q.aiff" "How do I earn the first badge"
afconvert -f WAVE -d LEI16@16000 -c 1 "$OUT/q.aiff" "$OUT/q.wav"
afconvert -f mp4f -d aac "$OUT/q.aiff" "$OUT/q.mp4"
clips=("$OUT/q.wav" "$OUT/q.mp4")
if command -v ffmpeg >/dev/null; then
  ffmpeg -loglevel error -y -i "$OUT/q.aiff" -c:a libopus -b:a 32k "$OUT/q.webm"
  clips+=("$OUT/q.webm")
else
  echo "ffmpeg missing: skipping WebM/Opus"
fi

run() {
  if [ -n "$DRY_RUN" ]; then echo "DRY_RUN: $*" | sed 's/Bearer [^ "]*/Bearer ***/'; else "$@"; fi
}

echo
echo "| Clip | HTTP | Transcript |"
echo "|---|---|---|"
for clip in "${clips[@]}"; do
  if [ -n "$DRY_RUN" ]; then
    run curl -sS --max-time 30 "$API/transcriptions" -H "Authorization: Bearer \$MISTRAL_API_KEY" \
      -F "model=$STT_MODEL" -F "file=@$clip"
    continue
  fi
  body="$OUT/$(basename "$clip").json"
  code=$(curl -sS --max-time 30 -o "$body" -w '%{http_code}' "$API/transcriptions" \
    -H "Authorization: Bearer $MISTRAL_API_KEY" -F "model=$STT_MODEL" -F "file=@$clip" || echo "curl-failed")
  text=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("text","").strip())' "$body" 2>/dev/null || head -c 200 "$body")
  echo "| $(basename "$clip") | $code | $text |"
done

tts() { # $1 = response_format, $2 = stream (true/false), $3 = output file
  run curl -sS --max-time 30 -o "$3" -w 'http=%{http_code} first_byte_s=%{time_starttransfer} total_s=%{time_total}\n' \
    "$API/speech" -H "Authorization: Bearer ${MISTRAL_API_KEY:-}" -H "Content-Type: application/json" \
    -d "{\"model\":\"$TTS_MODEL\",\"voice_id\":\"$TTS_VOICE\",\"input\":\"How do I earn the first badge\",\"response_format\":\"$1\",\"stream\":$2}"
}

echo
echo "TTS stream, pcm:"
tts pcm true "$OUT/tts.sse"
echo "TTS one file, wav (its header gives the PCM rate, bits and int or float):"
tts wav false "$OUT/tts.json"
[ -n "$DRY_RUN" ] && exit 0

echo "SSE event names: $(grep -o '"type": *"[^"]*"\|^event: .*' "$OUT/tts.sse" | sort | uniq -c | tr '\n' ' ')"
python3 -I - "$OUT/tts.json" "$OUT/tts.wav" <<'PY'
import base64, json, struct, sys
wav = base64.b64decode(json.load(open(sys.argv[1]))["audio_data"])
open(sys.argv[2], "wb").write(wav)
fmt, ch, rate, _, _, bits = struct.unpack("<HHIIHH", wav[20:36])
print(f"wav header: format={'int PCM' if fmt == 1 else 'float' if fmt == 3 else fmt} channels={ch} rate={rate} bits={bits}")
PY
