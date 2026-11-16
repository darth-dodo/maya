# PHASE_2.md: do not build in the MVP

New ideas land here, one line each, with the date added.

- Battle Frontier strategizer
- Realtime speech to speech
- Narrated recap
- Custom voice
- Other games
- Cloud-hosted factory
- Telegram bot, watcher and 21:00 digest (2026-11-14: Remote Control and the GitHub app cover the phone gate; the digest is `factory:recap`)
- Languages other than English, voice control of Dials other than humor, Walkthrough notes past Dewford (2026-11-14, PRODUCT.md out of scope)
- Browser Web Speech API voice fallback (2026-11-14: MVP shows text on a voice outage instead)
- Privacy at or above habla-hermano (2026-11-14). Hermano has: Fernet encryption at rest for personal fields and checkpoints, row-level security, a zero-retention header on LLM calls (with a test), a scheduled retention cleanup, account deletion and a privacy page. Maya already discards audio after STT. To go further: encrypt Conversation text at rest (AES-GCM with the key in Render env), zero-data-retention routing on every OpenRouter call (check its provider data-collection and ZDR options) with a test that asserts it, check and document Mistral's audio and text retention terms, a retention window for turns plus a "forget everything" voice command, no third-party scripts or analytics (CSP already self-only), RLS or a dedicated DB role on Supabase, and a privacy section in PRODUCT.md listing exactly what leaves the phone and where it goes
- "Talk slower" setting (2026-11-15): ask Voxtral for slower speech, never Web Audio `playbackRate` (lowers pitch; habla-hermano dccfdd1)
- Homepage demo clip with sound and captions (2026-11-15: tide-homepage removed the demo slot; "A real turn" shows one real turn as text)
- Stream agent tokens into TTS (2026-11-16, structured-answers): start speaking once the structured Answer's `answer` string closes in the stream, instead of after the whole reply
- Shared login (Plug.BasicAuth) on the Talk screen and browser pages (2026-11-16: guests use Maya without a login for now, ADR-008; #49 and draft #93 closed)
