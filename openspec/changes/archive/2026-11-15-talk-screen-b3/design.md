# Design

## Context

The Talk hook owns the voice state machine on `#talk-button`, which is `phx-update="ignore"`, so the hook's `data-state` there survives LiveView patches. The rest of the screen is server rendered, so a `data-state` set by JavaScript on the root would be reset by the next patch. The B3 mockup drives every visual from one `data-state` on the phone root.

## Decisions

1. **The root mirrors the hook through the server.** On each state change the hook pushes `talk_state` with the new state; `TalkLive` keeps it in `@talk_state` when it is one of the five known states and renders `data-state={@talk_state}` on `#talk-screen` and the status text in `#talk-status`. One source of truth, testable with `render_hook/3`, no patch fights. Cost: the ring, card shrink and status follow one socket round trip after the press. The button itself changes at once, because its labels are four server-rendered spans that CSS picks from the button's own `data-state`, which the hook sets locally. Audio playback never waits for the push. On reconnect the hook pushes its state again.
2. **Moment mapping.** Mockup moments map to hook states: talking = `recording`, waiting = `uploading` and `waiting`, Maya speaking = `speaking`, reading back = `idle`.
3. **Trainer card data.** `TalkLive` reads `GameData.progress/1`, `Horizon.next_gym/1` and `Horizon.badges_earned/1`. The gym type chip is the most common type across the leader's party (`GameData.trainer/1`, `GameData.species/1`), first seen wins a tie; with no game data loaded it is left out. Team type dots come from `GameData.species/1`. Read once on mount; Progress only changes through Start fresh, which reloads the page.
4. **Chat.** `Enum.take(turns, -3)`; the last gets class `now`. The older ones are faded with opacity at a size that stays at least 14 px, and the faded colour still meets 4.5:1 on the card colours.
5. **Scene colours.** The Talk screen keeps a fixed light scene (the mockup's sky and sea gradient, dark ink) in both themes, so contrast is checked once. Type chips use darkened type colours under white text (each at least 4.5:1).
6. **Pinned button.** `position: fixed` at the bottom with `max(1rem, env(safe-area-inset-bottom))`, and the chat reserves the space under it. The viewport meta gains `viewport-fit=cover` so the safe-area insets are real on iOS.
7. **No new assets.** The mic is an inline SVG; animations are CSS keyframes from the mockup, all off under `prefers-reduced-motion`.

## Risks

- One extra socket message per state change: tiny, and fire and forget.
- A state push that races a turns patch can render the old moment for one round trip; the next push corrects it.
