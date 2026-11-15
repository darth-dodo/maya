# Proposal

## Why

Maya still shows Phoenix's default favicon, has no link preview and cannot be added to an iPhone home screen as a full screen app. Search engines can also index it, although it has no login yet. GitHub Issue #85.

## What Changes

- Root layout `<head>`: meta description, `theme-color` for light and dark, Apple home screen tags, a manifest link, Open Graph and Twitter card tags with absolute URLs built from the endpoint's configured url, and `robots` noindex.
- A web app manifest at `/manifest.webmanifest` (standalone, start URL `/`, icons 192, 512 and a maskable 512).
- Original Emerald ball icon (`maya-icon.svg`) and its PNGs: favicon 16 and 32, apple-touch-icon 180, 192, 512, maskable 512, and a 1200 x 630 `og-image.png` made from `docs/assets/hero.svg`. Phoenix's default favicon is replaced.
- `robots.txt` disallows all until login (#49) lands.
- The CSP is unchanged: `default-src 'self'` already covers the manifest (`manifest-src` falls back to it) and `img-src 'self'` covers the icons.

Out of scope: service worker, offline mode, push notifications. New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities
- `site-metadata`: how Maya presents itself outside the page: browser tab, home screen app, link previews and search engines.

### Modified Capabilities

## Impact

`lib/maya_web/components/layouts/root.html.heex`, `lib/maya_web.ex` (`static_paths`), `priv/static/` (manifest, robots, images, favicon), new tests. No new dependencies.
