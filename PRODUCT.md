# PRODUCT.md: Maya

Last updated: 14 Nov 2026. Written from a `grill-with-docs` session with Abhishek. Terms in **bold** are defined in `GLOSSARY.md`.

## The job

> I'm stuck mid-route or before a gym. I hold the button, ask one question out loud, and within 5 seconds I hear a 2 to 3 sentence answer that fits my badges and team, with zero spoilers.

This is Maya's one job. Everything else (personality, journal, **Dials**) serves it or waits.

## Who and where

- One player: Abhishek, playing Pokemon Emerald on a GBA or DS, with Maya on a phone beside it. The phone is a dedicated Maya device.
- English only.
- One login (`Plug.BasicAuth`). No accounts, no other players.

## The experience

- **Screen:** a big **Talk button** and the full **Conversation** as a scrolling chat. Each **Answer** is spoken and shown as text.
- **Asking:** hold the Talk button, ask one **Question**, release. Holding the button while Maya speaks stops her at once and records the new Question; the cut Answer stays as text.
- **Answers:** 2 to 3 sentences, using the last 5 Questions and Answers as context, so follow-ups work ("what about Brawly?").
- **Answer time:** p50 at most 5 s, p95 at most 8 s on home Wi-Fi, measured per stage (mic release, STT, agent, TTS first byte, playback start).
- **When Maya can't answer well** (misheard, unsure, no Fact, past the **Spoiler horizon**), she says so in one short line, and offers a hint inside the horizon for a Spoiler. She never guesses a Fact and never fails silently.
- **Voice outage:** if speech to text or text to speech fails, Maya shows the Answer as text with a short "voice is down" note.

## What Maya knows

- **Progress** (badges, **Team**, location): seeded once by hand in `progress.json`, then kept current by **Events**. When the player says something like "I just earned Roxanne's badge", Maya updates Progress and confirms in one line ("Stone Badge logged. Mudkip would approve."). The player can say "no" to undo.
- **Facts** come only from Maya's own data and tools, never from the model's memory (ADR-004). No Fact means "Not sure".
- **Game data:** all of Hoenn is imported once (pokeemerald `wild_encounters.json` and `trainer_parties.h`, PokeAPI for Emerald). The Spoiler horizon decides what Maya may use.
- **Walkthrough notes:** short, original notes per location from Littleroot to Dewford (up to Brawly), written by Claude from the game data and not reviewed by Abhishek. Wrong directions surface when Maya says them; they get fixed as found.
- **Audio** is sent to speech to text and dropped; only the transcript is kept in the Conversation.

## Spoilers

- The **Spoiler horizon** is the **Next gym**: Maya may talk about everything up to and including it (routes, wild Pokemon, trainers, items, story) and nothing past it.
- Asking directly never unlocks past the horizon. The **Spoilers dial** is fixed at 0.

## What Maya can answer in the MVP

1. **Gym counters:** "How do I earn Roxanne's badge with my team?"
2. **Where to catch:** "Where do I find a Ralts?" (within the horizon)
3. **Pokemon facts:** "What's Geodude weak to?" (types, weaknesses, evolution level)
4. **Where to go next:** "I'm stuck, where now?" (from Walkthrough notes)
5. **Humor dial:** "Maya, humor 60 percent" changes it live, TARS style, and she confirms out loud.

## Character

- Human-like, with opinions, the **Catchphrase** "Mudkip would approve.", and Mudkip hype 100.
- Inclusive language: Maya talks about earning badges, battling and getting past a gym, never "beat" or "defeat".
- Dials: humor 75 (changeable by voice), honesty 90, sass 40, spoilers 0 (locked), Mudkip hype 100. Only the **Humor dial** changes in the MVP.

## Done when (Sunday)

On the phone over HTTPS, with Progress at 0 badges and the real Team:

1. Hold the Talk button and ask "How do I earn Roxanne's badge?": hear 2 to 3 sentences that name a counter from the Team and Roxanne's ace.
2. In the same Conversation, ask "Where do I catch a Ralts?": hear where, within the horizon.

Both Answers must also meet the quality bar:
- **Answer time** under 8 s.
- **Zero Spoilers:** nothing past Rustboro in either Answer, or in a 20-question spoiler probe set.
- **Facts correct:** every Fact matches the game data (Roxanne's team, Ralts locations).
- **Talk button never sticks:** 10 holds in a row each produce exactly one Question.
- **Code quality:** all CI gates green (`ci-success`), coverage floor never lowered, no blocking `factory:review` findings.

## Out of scope (PHASE_2.md)

Battle Frontier strategist, realtime speech to speech, narrated recap, custom voice, other games, more players, languages other than English, voice control of Dials other than humor, Walkthrough notes past Dewford.

## Risks

- **Unreviewed Walkthrough notes** can give wrong directions out loud.
- **Answer time** depends on three external services (STT, OpenRouter, TTS) and a cross-region database (ADR-002).
- **Tools-only Facts** mean more "Not sure" Answers until the data covers the question (ADR-004).
