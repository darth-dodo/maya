# Design

## Context

`home.html.heex` renders the hero (`#maya-hero`) and the badge case inside `Layouts.app`. `PageHTML` only embeds templates. The CSP in `lib/maya_web/router.ex` allows no extra inline script, and the page has no Progress, so the spoiler horizon is a new save before the first gym.

## Goals / Non-Goals

**Goals:** about 12 correct, fun, spoiler-free facts; rotation without JavaScript; accessible to screen readers and to reduced motion.
**Non-Goals:** Progress-aware facts, controls (pause, next), facts from the database or agent tools.

## Decisions

- **Facts as a module attribute** `@poke_facts` in `MayaWeb.PageHTML` with a `poke_facts/0` function the template calls. Alternative: a database table; rejected, 12 static strings do not need one.
- **CSS only rotation:** every fact sits in one grid cell (`grid-area: 1 / 1`), so the list is as tall as the longest fact and nothing overflows. Each item runs the same 96 s keyframe animation (visible for one twelfth of the cycle) with an `nth-child` delay of 8 s per item. No inline `style` attributes, so the CSP is untouched.
- **Accessibility:** hidden facts use `opacity: 0` only, so screen readers still read the whole list; the list has `aria-label="Poke facts"`. With `prefers-reduced-motion: reduce` the animation is off and only the first fact is visible; the others stay in the accessibility tree.
- **Look:** a small Emerald card (black border, pale tide green) that reuses the hero palette variables.

## Facts and sources

Encounter rates: the Emerald land slot rates are `[20,20,10,10,10,10,5,5,4,4,1,1]` percent, from the `fields` entry `land_mons` in `wild_encounters.json`. Only land encounters count: water and fishing need Surf or a rod, which a new save does not have before the first gym.

- WE = https://raw.githubusercontent.com/pret/pokeemerald/master/src/data/wild_encounters.json
- PA = https://pokeapi.co/api/v2/

| Fact | Source |
|---|---|
| Mudkip is a pure Water type, and Maya is not biased at all. | PA `pokemon/mudkip`: types `[water]`, no past types |
| Treecko is a pure Grass type. | PA `pokemon/treecko`: types `[grass]` |
| Torchic is a pure Fire type. | PA `pokemon/torchic`: types `[fire]` |
| All three Hoenn starters evolve at level 16 and again at level 36. | PA `evolution-chain/130`, `131`, `132`: `min_level` 16, then 36 |
| Poochyena is a Dark type found on every route from 101 to 104 and in Petalburg Woods. | PA `pokemon/poochyena`: `[dark]`; WE `gRoute101` to `gRoute104` and `gPetalburgWoods` land_mons |
| Zigzagoon is a Normal type you can meet on Routes 101, 102 and 103. | PA `pokemon/zigzagoon`: `[normal]`; WE `gRoute101`, `gRoute102`, `gRoute103` land_mons |
| Wurmple evolves at level 7 into either Silcoon or Cascoon. | PA `evolution-chain/135`: silcoon and cascoon, `min_level` 7 |
| Ralts hides in the Route 102 grass with just a 4 percent encounter rate. | WE `gRoute102` land_mons slot 9 (4 percent), the only Ralts slot |
| Seedot is the rarest find on Route 102: a 1 percent encounter. | WE `gRoute102` land_mons slot 11 (1 percent), lowest rate on that route |
| Lotad is a Water and Grass type living in the Route 102 grass. | PA `pokemon/lotad`: `[water, grass]`; WE `gRoute102` land_mons slots 4 and 5 |
| Wingull is a Water and Flying type that turns up on Routes 103 and 104. | PA `pokemon/wingull`: `[water, flying]`; WE `gRoute103`, `gRoute104` land_mons |
| Slakoth naps in Petalburg Woods and shows up in 5 percent of encounters there. | WE `gPetalburgWoods` land_mons slots 9 and 11 (4 + 1 percent) |

The page shows these 12 facts in this order (`lib/maya_web/controllers/page_html.ex`).

Not used: Ralts and Marill types (PokeAPI lists Fairy, added after Emerald; `past_types` shows Psychic and Water only), Wurmple's evolution split rule (not in PokeAPI or WE).

## Risks / Trade-offs

- [Opacity-hidden facts are read by screen readers in one go] → intended: the visual rotation is presentational, the list is the content.
- [Fixed 96 s cycle ties to the fact count] → the `nth-child` delays cover 12 items; a test pins the count range, and a comment in the CSS says to update both.

## Migration Plan

Single deploy; rollback by reverting the PR.
