# Design

## Context

See proposal.md for why. STT sends `model`, `language` and `file` (#59). Game names live in Postgres (`species`, `locations`) and in `Maya.Horizon` (gym leaders and cities). The agent reads the Guest's Progress at the start of its stage.

### The API, verified 2026-11-15

- Field: `context_bias` on `POST /v1/audio/transcriptions`. "Repeat the `context_bias` form field once per entry", one term per entry; multi-word entries are allowed ("Alder Creek Design"). Supported for file transcription by `voxtral-mini-transcribe-3` and `voxtral-small-transcribe-3`.
  Sources: https://docs.mistral.ai/studio/audio/speech-to-text/transcribe-files (section "Context bias") and https://docs.mistral.ai/studio/audio/speech-to-text/bias-context-and-vocabulary.
- Limit: no count or per-entry limit is documented. The 65,536 token context window is shared by the audio and `context_bias`; over it the request fails with `400` (`invalid_request_prompt_too_long`) and "nothing is cut". Source: https://docs.mistral.ai/studio/audio/specs-and-limits/limits.

## Goals / Non-Goals

**Goals:** names come through STT as spoken; a near miss that still slips through is fixed before the agent; a turn still reads Progress once.

**Non-Goals:** free-form context text, realtime STT, other languages, a full English dictionary at runtime.

## Decisions

1. **Terms.** `Maya.Voice.Vocabulary.bias_terms(progress, names)` is pure. Order: "Maya", "Mudkip", the Team, the Next gym leader, locations inside the horizon, then every species, gym leader, gym city and location. Species display names are the PokeAPI names capitalised (`ralts` is "Ralts"). Deduplicated, then capped at 400 terms. Today the list is 291 terms and 2,178 bytes of text, far inside the shared window, so the cap never cuts; it exists so a larger data set can never fail every Question with a `400`. We cap by count, not tokens, because the docs give no tokenizer for bias terms; by our estimate 400 short names stay in the low thousands of tokens (unverified).
2. **Cache.** Species and location names come from Postgres, so a compile-time attribute is wrong. `names/0` keeps them in `:persistent_term`, loaded on first use and erased by `GameData.import!/1`. Game data changes only on import, so the cache is read-only in normal use. Building the terms from the cache is pure list work on about 300 strings per turn.
3. **One Progress read.** The Conversation reads Progress in the STT task (for the Team and horizon) and passes it to `Agent.answer/3` as `progress:`, so the agent does not read it again. The read moves from `agent_ms` to `stt_ms`.
4. **Correction.** `correct(transcript, terms)` splits on spaces, keeps leading punctuation and a trailing "'s" or punctuation, and compares lowercase words to the single words of the terms ("Rustboro City" gives "rustboro" and "city"). A word snaps when its best Jaro distance is at least 0.86, it starts with the same letter, it is not a prefix of the name ("torch", "seed", "star"), the lengths differ by at most 2, it has 4 or more letters and it is not on the English guard list. Two adjacent words are joined and snap when the joined form scores higher than either word alone ("torch ick" to "Torchic", "nose pass" to "Nosepass"). An exact match is left as spoken.
5. **Threshold 0.86.** Tuned on the issue's misses: "rawls" scores 0.867 against "ralts", "torchick" 0.958, "zigzaggoon" 0.967. At that level Jaro alone also hits English words, some at higher scores ("golden" 0.952 for Goldeen, "electric" for Electrike, "around" for Aron, "rails" 0.867 for Ralts, the same score as "rawls"). No threshold separates "rawls" from "rails", so the guard is data, not a number.
6. **English guard.** `priv/data/english_guard.txt` lists every word of Webster's Second (`/usr/share/dict/words`, public domain), plus its `s`, `es`, `ed` and `ing` forms, that would snap under rule 4. `scripts/english_guard.exs` regenerates it from the term list and the threshold; rerun it when names or the threshold change. Shipping the full dictionary (2.4 MB) was rejected for memory on the 512 MB instance.

### Spoiler risk

None. Bias terms only steer recognition: they go to Voxtral in the STT request and are never shown, stored or sent to the model. The model sees only the corrected transcript, which holds names the player said. A past-horizon name can appear in a Question only when the player said it, and the tools still apply the horizon before any Fact reaches the model (ADR-004).

## Risks / Trade-offs

- A real miss that lands on an English word in the guard stays uncorrected ("rails" for Ralts). The bias is the main fix; the correction is a backstop, and the model can still map a near name in a tool call.
- An English word missing from Webster's Second (slang, new words) could still snap. Accepted: it must also pass the first-letter, prefix and length rules.
- The STT request grows by 291 form fields: 29,279 bytes with multipart framing, measured locally with `Req.Utils.encode_form_multipart/2`. Locally, building the terms takes about 0.9 ms warm and `correct/2` about 5 ms for a 14 word Question (`:timer.tc`, 100 runs). Real before and after `stt_ms` needs the deployed app (Supabase query on Issue #40); not measured here.
