Changed: The Talk screen, homepage and `/factory` follow the theme on the design tokens: Calm Emerald by day, Emerald night at night (deep night sea, gold hairline on the trainer card, the ball glows); Fraunces for headings and the gym line, Inter for Answers and labels
Changed: The footer art, `theme-color` metas (`#0f5a3a` light, `#08181a` dark), manifest colours, `maya-icon.svg`, `logo.svg`, README `hero.svg` and `footer.svg` use only palette values; favicon, app icons and `og-image.png` re-rendered from them
Changed: The colour gate allow list is empty: no colour literal is left outside the token layer
Fixed: The sticky trainer card stays compact and opaque with a full Team (chips wrap across the card) (#117)
Fixed: The "Yes, start fresh" button text reaches 4.5:1 by day (`btn-error`, was `btn-warning` at 4.29:1); the theme toggle buttons are 44 px targets
