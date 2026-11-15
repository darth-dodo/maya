# Proposal: tide-homepage

## Why

#130 (design-apply) put the Calm Emerald tokens on every page, but the homepage still has its old layout: a centred ball, two phone-frame screenshots, a boxed voice loop and a boxed promise list. On 2026-11-15 Abhishek picked a visible redesign from the mocks canvas (https://claude.ai/artifact/MVn8DqEgNg2Mo3mmgx9nPf): direction "A Tide" for the homepage, plus the personality sections from "F Maya herself". This change covers the homepage. The Talk screen is its sibling change, `tide-talk`.

## What Changes

Homepage `/`, in this order:

1. **Hero** (about 560px tall on a phone): the tide backdrop full bleed, or the night backdrop at night, fading into `--maya-bg`. The header reads "Maya" with an "Open Talk" link. Then the eyebrow "A Pokémon Emerald companion", the Fraunces headline "Ask out loud. No spoilers.", one line of body copy, the "Talk to Maya" pill and the mic note.
2. **A real turn, Route 104**: one real Question (small, right aligned, muted) and Maya's real Answer as large unboxed text, with a caption giving the median Answer time (4.95 s over 145 turns). The value is kept in one place so it is easy to update.
3. **Meet Maya. She has opinions.** The ball as her avatar with the speech bubble "So I hear you like Mudkip. Good. Correct choice.", her Dials as read-only bars that describe her (humor 75, honesty 90, sass 40, Mudkip hype 100, spoilers 0 locked), and "Things she says": 3 lines as bubbles, two from her prompt and her Mudkip hype line.
4. **How a turn works**: the 4 voice loop steps as numbered, ruled lines with no boxed cards.
5. **Spoiler promise band** on `--maya-sea`: "Further ahead, no spoilers." in Fraunces, plus the CI spoiler gate sentence.
6. **Footer**: unchanged links (How Maya is built, GitHub, README).

- **BREAKING (spec):** the `h1` changes from "Maya" to "Ask out loud. No spoilers." The ball and the catchphrase move from the hero to "Meet Maya".
- **Removed:** the demo slot (the two screenshots), the planned demo clip slot, and the `#promise-facts` and `#promise-horizon` items. "A real turn" replaces the screenshots; design.md explains why the images are deleted.

Out of scope: Dials as controls or any "ask her to change them" copy (Dials are cut order item 3; only the Humor dial changes, by voice, in #41), a demo video, new copy beyond what is listed here, the Talk screen (`tide-talk`), and a theme switch. New ideas go to PHASE_2.md.

Builds on #130 (merged 2026-11-15 as 5416f53). The build Issue starts from that main.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `landing-page`: new hero, "A real turn", "Meet Maya" with read-only Dials and real sayings, ruled loop steps, a promise band, the demo slot and clip removed.

## Impact

- `lib/maya_web/controllers/page_html/home.html.heex` (rewritten), `page_html.ex` (the real turn and Dial values replace `screenshots/0`), `page_controller.ex` (no more `demo_transcript`), `assets/css/app.css` (homepage block), `lib/maya_web/components/layouts.ex` (header "Open Talk" link on `/` only).
- `priv/static/images/demo/` deleted. No new dependency, no new route, no LiveView socket on `/`.
- `test/maya_web/controllers/page_controller_test.exs` updated to the modified scenarios. The colour gate, contrast and font tests stay green.
- Not the voice loop, so no latency numbers change. `app.css` is on the E4 phone check list, so the PR carries a "Phone check:" line.
- Issue: filed by `factory:plan` and linked from the spec PR.
