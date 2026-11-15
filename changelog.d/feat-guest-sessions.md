Added: Guest sessions (ADR-008): every browser gets a random `guest_id` in the signed session cookie (kept for a year) and its own Conversation and Progress; a new Guest's Progress is seeded from `priv/progress.json` on first use
Added: "Start fresh" on the Talk screen, with an in-page confirm step, gives the browser a new Guest; the old rows stay in Postgres
Changed: A Conversation stops after 30 idle minutes and reloads its turns from Postgres on the next visit or Question
Changed: The release import seeds game data only; existing turns and Progress belong to the Guest `legacy`
