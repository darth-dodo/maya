---
name: settled-architecture
description: Use before proposing a new library, service, host, model provider or architecture change in Maya, or when a task seems to need something outside the frozen MVP stack
---

# Settled architecture

The MVP stack is frozen. Build inside it. Changing it needs Abhishek's explicit yes and an ADR in `docs/adr/`.

| Concern | Settled | Explicitly NOT |
|---|---|---|
| Web | Elixir, Phoenix + LiveView | React, Vue or any SPA, a separate API server |
| Data | Postgres + pgvector (`{:pgvector, "~> 0.4"}`) on Supabase free, Ireland eu-west-1 (ADR-002) | A separate vector DB, Redis, SQLite, Render Postgres |
| Agent LLM | OpenRouter, tool calling via Req, model name in config | Direct provider SDKs, hard-coded model ids |
| Agent loop | Hand-written GenServer | LangChain, Jido or any agent library |
| STT / TTS | Mistral `voxtral-mini-transcribe-3`, Voxtral TTS 3; `voxtral-mini-transcribe-realtime-3` for the live preview, server side over `mint_web_socket`, batch as final and fallback (ADR-009) | Other voice vendors, including the browser Web Speech API; a browser to Mistral connection; other WebSocket clients. On a voice outage Answers show as text (PRODUCT.md) |
| Embeddings | Mistral embeddings API | Bumblebee or any local model (Render has 512 MB) |
| Hosting | Render web service, Frankfurt | Other hosts or regions |
| LLM tracing | Langfuse Cloud Hobby, EU, over OTLP/HTTP with `opentelemetry` 1.7, `opentelemetry_api` 1.5, `opentelemetry_exporter` 1.11; numbers and tool names only, off without both keys (ADR-010) | Content in spans (Question, Answer, prompt, history, tool arguments or results, Progress, guest ids), other tracing vendors, self-hosted Langfuse, paid plans |
| Auth | `Plug.BasicAuth` | `phx.gen.auth`, OAuth, user accounts |

## Red flags: stop and ask

If you catch yourself thinking any of these, stop and ask Abhishek instead of building around the decision:

- "A small library would make the agent loop cleaner."
- "This model or provider is faster, I'll just call it directly."
- "A local embedding model avoids an API call."
- "This needs a JS framework for the audio UI."
- "Realtime speech to speech would be better." (That is PHASE_2.md.)
- "I'll add it now and we can remove it later."

New ideas go to `PHASE_2.md`, never into the MVP.
