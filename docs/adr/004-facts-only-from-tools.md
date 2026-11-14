# 004: Facts only from tools and data

- Status: Accepted
- Date: 2026-11-14

## Why

- Language models know a lot of Pokemon, including everything past the player's Spoiler horizon, and they misremember details (levels, locations, moves). A confident wrong fact or an accidental spoiler breaks Maya's one promise.
- The Spoiler horizon can only be enforced on data Maya controls.

## What

Every Fact in an Answer comes from a tool (`find_pokemon`, `gym_counter`, `search_guide`) over Maya's own data, filtered by the Spoiler horizon. The model phrases the Answer and adds personality, but adds no facts of its own. When no tool returns a Fact, Maya says she is not sure (PRODUCT.md, "When Maya can't answer well").

## How

- The agent's system prompt forbids game facts that are not in a tool result for this turn.
- Tools apply the Spoiler horizon before returning data, so out-of-horizon facts never reach the model.
- The spoiler probe set and the Sunday test check both rules.

## Consequences

- Easier: no spoilers from model memory; every Fact is traceable to imported data.
- Harder: more "Not sure" Answers until the data and Walkthrough notes cover a question; data gaps show up as product gaps.
- Revisit when: "Not sure" Answers dominate real use, then widen the data, not the model's freedom.
