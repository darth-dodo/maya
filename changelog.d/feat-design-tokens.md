Added: Design tokens for Calm Emerald (day) and Emerald night in `assets/css/app.css`: colour, type, radius, shadow and motion, with daisyUI themes on the tokens (primary is emerald, no Phoenix purple)
Added: Self-hosted Fraunces (headings) and Inter (body) woff2 files with their SIL OFL 1.1 licences; one Inter preload
Added: `docs/design-system.md` and tests for token coverage, contrast pairs, the font route and a colour gate that fails on colour literals outside the token layer
Changed: Reduced motion turns every animation off through `--maya-duration`; the night `theme-color` is the night background `#08181a`
