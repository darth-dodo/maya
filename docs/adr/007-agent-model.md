# 007: Agent model

- Status: Proposed
- Date: 2026-11-14

## Context

The agent stage sits on the path to first sound, so Answer time (p50 at most 5 s, p95 at most 8 s) depends on it. ARCHITECTURE.md 3 says Block 3 runs the Roxanne Question through 2 or 3 fast models that support tools and keeps the one with the best agent-stage latency that gets the Facts right.

Candidates, all listed with tool support on `https://openrouter.ai/api/v1/models?supported_parameters=tools` on 2026-11-14:

| Model | Prompt $/M tokens | Completion $/M tokens |
|---|---|---|
| `anthropic/claude-haiku-5.5` | 0.10 | 0.50 |
| `google/gemini-3.8-flash` | 0.375 | 1.875 |
| `openai/gpt-5.4-mini` | 0.375 | 2.25 |

The builder had no `OPENROUTER_API_KEY`, so no numbers are measured yet. `anthropic/claude-haiku-5.5` is the config default until they are.

## Decision

Keep the model with the lowest agent-stage milliseconds whose Answer names Nosepass (level 15) as Roxanne's ace and Mudkip as the counter, in 2 to 3 sentences, with no Fact outside the tool result. Set it as `agent_model` in `config/config.exs`.

How to measure (with `OPENROUTER_API_KEY` set and the database imported):

```
mix maya.compare_models
```

Run it 3 times and record the median per model.

| Model | Agent ms (median of 3) | Names Nosepass 15 | Names Mudkip | 2 to 3 sentences | Kept |
|---|---|---|---|---|---|
| `anthropic/claude-haiku-5.5` | | | | | |
| `google/gemini-3.8-flash` | | | | | |
| `openai/gpt-5.4-mini` | | | | | |

## Consequences

- Easier: the model is one config value; `mix maya.compare_models <model>` rechecks any newcomer.
- Harder: a model that skips the tool call answers from memory; ADR-004's rules depend on the prompt being followed, which Block 4's spoiler probe set checks.
- Check: agent ms in `mix maya.latency` after the switch; revisit if agent p95 passes 3 s.
