## Why

Voxtral STT turns Pokémon, place and gym names into ordinary English words ("Hendelmeyer, also born.", "Fire and go market."), so the tools never find the Fact and Maya answers "Not sure". Issue #68.

## What Changes

- STT sends `context_bias`, one multipart field per term, built by a pure function from game data: Maya, Mudkip, the Guest's Team, the Next gym leader, locations inside the Spoiler horizon, then every other species, gym leader, gym city and location Maya knows; deduplicated and capped.
- A pure post-STT correction snaps a near-miss word, or two words spoken apart ("torch ick"), to the nearest known name when `String.jaro_distance/2` is high, and never changes a word from a committed list of English words that sit near a name.
- The Conversation reads the Guest's Progress once in the STT stage, uses it for the bias terms, and hands it to the agent, so a turn still reads Progress once.
- The shown and stored Question is the corrected transcript.

## Capabilities

### New Capabilities

### Modified Capabilities
- `voice-loop`: STT is biased toward known names and its transcript is corrected before the agent.

## Impact

- Code: new `Maya.Voice.Vocabulary`, `Maya.Voice.STT.transcribe/3`, `Maya.Conversation` STT stage, `Maya.Agent.answer/3` takes an optional `progress`, `Maya.GameData.import!/1` refreshes the cached names.
- Data: `priv/data/english_guard.txt` (generated from the public domain Webster's Second word list by `scripts/english_guard.exs`).
- STT request grows by 291 short form fields (about 29 KB with multipart framing). Latency before and after needs the deployed app.

## Out of scope

- Other STT vendors (frozen stack), languages other than English, free-form context text, realtime STT.
