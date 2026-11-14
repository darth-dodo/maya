# Design

## Context

`home.html.heex` renders the flash group, an `h1` and a `p`, without `Layouts.app`. `Layouts.app` (`lib/maya_web/components/layouts.ex`) still holds the generator header: Phoenix logo, version, Website, GitHub and Get Started links, plus the theme toggle. Styling is Tailwind v4 with daisyUI themes in `assets/css/app.css`. Review of #16 asked for DOM ids and id-based tests (AGENTS.md:142, :374, :375) and flagged the header links.

## Goals / Non-Goals

**Goals:** a recognisably Poke Ball themed page that stays original; follow the AGENTS.md layout pattern; testable by ids.
**Non-Goals:** a new daisyUI theme; real badge state; images of any kind.

## Decisions

- **Adopt `<Layouts.app flash={@flash}>`** and replace its header with a Maya wordmark and the theme toggle; drop the logo, version and the three Phoenix links. Alternative: keep the page standalone; rejected, AGENTS.md:10 makes `Layouts.app` the pattern and the header would stay a trap.
- **Poke Ball with CSS only:** a circle split red over white by a black band with a centre button, built from nested `div`s and Tailwind arbitrary values, no SVG files or images. Alternative: an inline SVG; acceptable but heavier to keep original-looking.
- **Palette** as three CSS custom properties in `app.css` (`--pokeball-red`, `--pokeball-white`, `--pokeball-black`), applied to the hero only, so daisyUI light and dark themes stay intact.
- **Badge case:** 8 slots rendered from `1..8` in the template, `data-earned="false"`, `aria-label="Badge N of 8"`, grey outline style; no names, so the spoiler guard holds. When progress exists, a later block flips `data-earned`.
- **Copy** fixed by the spec: Mudkip line, tagline. "Pokemon" written without the accent in copy, matching the tagline.
- **Tests:** one helper that parses with `LazyHTML` and selects by id; spoiler test refutes every Hoenn leader and badge name; original-art test checks every `src` and stylesheet `href` is relative and there is no `img`.

## Risks / Trade-offs

- [Trademark: "Pokemon" and "Poke Ball" are Nintendo and Game Freak marks] → text references and an original CSS shape only, no logos, sprites, fonts or official colours copied from assets; fan project.
- [CSS ball looks off on small screens] → fixed size in `rem`, centred; check at 375 px width.
- [Removing the theme toggle from generator page earlier] → it returns via `Layouts.app`.

## Migration Plan

Single deploy; rollback by reverting the PR.
