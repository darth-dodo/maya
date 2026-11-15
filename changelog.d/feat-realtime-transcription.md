Changed: The Talk button streams the held Question as 200 ms PCM chunks over the LiveView socket instead of one upload on release; the final Question shows as soon as it is transcribed
Added: Voxtral realtime STT relay (`mint_web_socket` 1.0.6) with live words in the Guest's bubble while held, off unless `MAYA_STT_REALTIME=true`; batch STT stays the final source and the fallback (ADR-009)
Added: `turns.stt_source` and `mix maya.stt_eval` (realtime spike, Voxtral TTS eval clips, WER and name accuracy for batch and realtime)
