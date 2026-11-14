Added: Maya answers Questions with a hand-written agent loop over OpenRouter tool calling (at most 4 rounds, malformed tool arguments handled), using the last 5 turns as context
Added: `gym_counter` and `find_pokemon` tools that return Facts from Maya's own data inside the Spoiler horizon, or not found, or past the horizon
Added: System prompt with the Answer rules (Facts only from tools, no spoilers, "Not sure", 2 to 3 sentences, Dials, Catchphrase, inclusive language)
Added: `turns.agent_ms` and the agent stage in `mix maya.latency`; `mix maya.compare_models` and ADR-007 (Proposed) for the agent model choice
Changed: The Answer is no longer an echo; an agent failure speaks "Lost my train of thought, ask again?"
Changed: `OPENROUTER_API_KEY` is read in `config/runtime.exs` and listed in `render.yaml`
