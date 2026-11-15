# Design: guide-and-humor

## Context

`locations.json` is hand-written and is the only horizon map (fail closed, ARCHITECTURE.md decision 8). Progress already has a `humor` column, seeded at 75 and read into the prompt, but nothing writes it. `Tools.encode/2` already knows `{:logged, line, progress}` and `{:refused, line}` from `log_event`.

## Goals / Non-Goals

**Goals:** notes that can never name a place past their own horizon; one Dial changeable by voice.

**Non-Goals:** search by free text or embeddings (SQL by location name only, decision 4).

## Decisions

- **One note per location, tagged with the location's `badges_required`.** Keeps the horizon in one table. A note may name only listed locations whose `badges_required` is at most its own; a test checks every note's text against every other location name and the forbidden list. So Rustboro City's note (0) cannot point to Route 116 (1); the hint from `past_horizon` covers "what next" after Roxanne.
- **Unlisted means `past_horizon`, not `not_found`.** Answering "not found" for a made-up name and "further ahead" for Mauville would tell the Guest Mauville exists.
- **`set_setting` reuses the `log_event` result shapes.** `{:logged, line, new_progress}` and `{:refused, line}` encode as `confirm` and `refused`, so the loop and the #118 honesty check treat both write tools the same way.
- **Humor is a setting, not an Event.** Events change the player's game (ADR-006); the Dial changes Maya. Saying a new value replaces it.
- **Name matching:** trimmed, case-insensitive, a leading "the" dropped; no fuzzy match, so a mishearing becomes `past_horizon` with a hint rather than the wrong place.

## Risks / Trade-offs

- [Unreviewed notes give wrong directions out loud (PRODUCT.md risk)] → notes are built only from Maya's data files; wrong ones get fixed as found.
- [A Guest at an unlisted location asks "where now?"] → `past_horizon` with the Next gym hint, never a guess.
