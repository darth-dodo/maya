# Design: tide-homepage

## Context

After #130 the homepage (`home.html.heex`) is on the tokens. It is still a centred hero with the ball, a `#demo` section fed by `screenshots/0` in `page_html.ex` and `demo_transcript` from `page_controller.ex`, a boxed `#voice-loop` and a three-item `#spoiler-promise`. The colour gate, the contrast test and the font test already cover the page. The CSP allows inline `style` attributes (`style-src 'self' 'unsafe-inline'`).

## Goals / Non-Goals

**Goals:** the Tide layout of proposal.md, built with existing tokens and classes. The page stays static (no LiveView socket) and correct in both themes, under reduced motion and at 375px.

**Non-Goals:** new tokens (if a pair needs a new colour, stop and ask), Dials as controls, a demo video, and any copy change to the Talk screen.

## Decisions

1. **Backdrop as a CSS background, not an `img`.** `#home-hero` gets `background-image: url(/images/backdrops/tide.jpg)` on `:root` and `night.jpg` in both night blocks (the same pattern as the tokens), plus a `linear-gradient` to `var(--maya-bg)` at the bottom for the fade. The image is decorative, so no `alt` text is needed and the "no `img`" rule stays simple. Text over the art sits on the faded area or on a `--maya-bg` scrim, so it is checked against `--maya-bg` (existing contrast pairs). The alternative, an `img` with `object-fit`, adds an alt text and a load order to handle for no gain.
2. **Demo images deleted.** The screenshots in `priv/static/images/demo/` are referenced only by `screenshots/0` and its test (grep of `lib`, `test`, `docs` and `README.md`). With `#real-turn` they are dead weight and would go stale with the redesign. Delete them, `screenshots/0`, `demo_transcript` and the video branch. Deleting is cheaper than keeping assets nobody shows.
3. **One recorded value for the real turn.** A module attribute `@real_turn` in `page_html.ex` holds `question`, `answer`, `median_s` (4.95), `turns` (145) and a one-line source comment (where the median came from and on what date). The caption is built from it, so updating it is a one-line edit. The Question and Answer are copied word for word from a stored turn at Route 104 that Abhishek picks. The builder asks for it on the Issue if it is not given, and never writes one.
4. **Dials from one list.** `@dials` in `page_html.ex` lists `{name, value, locked?}`. Each bar's width comes from an inline `style="--dial: 75%"` on a `.dial-bar` that is `aria-hidden`; the name and value are real text, so screen readers read "Humor 75". There is no `<meter>`, which looks different on each browser and suggests a live gauge. A test compares the values with `Maya.Agent.Prompt` and the seed humor (75), so they cannot drift.
5. **Sayings are quoted, not written.** The 3 bubbles are "Mudkip would approve." (the Catchphrase, prompt rule 6), "Further ahead, no spoilers." (prompt rule 2) and "The Team is full at 6, so I left it as is." (`events.ex`). A test greps the two source files for each line. The hero catchphrase stays in `#home-catchphrase` as the Meet Maya bubble.
6. **Mic note copy.** The mocks said "The mic is on only while you hold." The warm mic keeps it open up to 4 s after a turn (talk-screen "Mic only while held"), so that line would not be true. The spec uses "The mic is on while you hold, and off a few seconds after." Abhishek can veto on the spec PR.
7. **"Open Talk" only on `/`.** `Layouts.app` gains an optional `:header_link` slot or attribute that `home.html.heex` fills. `/talk` and `/factory` keep the header as it is.
8. **Spoiler band.** Only the CI gate item stays. `#promise-facts` and `#promise-horizon` are dropped as the mocks show, because ADR-004 and the Spoiler horizon are what the heading already promises.

## Risks / Trade-offs

- [Heading text over a photo fails contrast in one theme] → keep text on the faded part, check with the contrast test pairs plus a computed style check in the PR.
- [64px Fraunces headline wraps badly at 320px] → `clamp()` down to about 48px under 360px; the 375px scenario still holds.
- [The real turn text contains a spoiler] → the page-wide spoiler scenario runs on it; Route 104 is inside the horizon at 0 badges.
- [The median goes stale] → the source comment carries the date; `release-manager` can refresh it.

## Migration Plan

One PR, static page only. Roll back by reverting the squash commit; no data or route change.
