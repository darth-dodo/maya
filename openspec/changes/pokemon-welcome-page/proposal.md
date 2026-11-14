# Proposal

## Why

The landing page proves the pipeline but says nothing about what Maya is for. A Pokemon Emerald themed welcome page sets the tone for a fan companion, and it is the first real feature to go through the factory after the dry run. It also closes the four non-blocking review findings from #16.

## What Changes

- The home page gets a Poke Ball themed hero: a red, white and black palette and a Poke Ball drawn with CSS only.
- A Mudkip hype line (Mudkip hype dial is 100).
- A spoiler-free badge case: 8 empty badge slots, numbered, with no gym, leader or badge names. Later blocks fill them as badges are earned.
- Original art only: no official artwork, logos, sprites or fonts, and no third-party images, fonts or scripts.
- The page adopts the app layout (`Layouts.app`), with the generator's Phoenix links, logo and version removed from its header so it shows Maya instead.
- Review findings from #16: stable DOM ids on key elements, tests select elements by id instead of matching raw HTML.
- Out of scope: real badge progress, push-to-talk, LiveView, sound, animations beyond CSS hover, light and dark theme redesign.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `landing-page`: identity elements get stable ids; the no-framework rule now also covers the app layout header; adds the themed hero, Mudkip hype, the spoiler-free badge case and the original-art rule.

## Impact

- `lib/maya_web/controllers/page_html/home.html.heex`, `lib/maya_web/components/layouts.ex` (app header), `assets/css/app.css` (Poke Ball palette and ball styles).
- `test/maya_web/controllers/page_controller_test.exs`.
- `priv/static/images/logo.svg` no longer referenced (left in place).
