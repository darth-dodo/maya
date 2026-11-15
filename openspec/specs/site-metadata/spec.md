# site-metadata Specification

## Purpose

How Maya presents itself outside the page: the browser tab, the phone home screen app, link previews and search engines.

## Requirements

### Requirement: Page metadata
Every browser page SHALL carry the title "Maya", the description "Maps, Answers, Yaps, Advice. A spoiler-free Pokémon Emerald companion.", an Emerald green `theme-color` for light and for dark colour schemes, and a viewport with `viewport-fit=cover`.

#### Scenario: Head tags on the Talk screen
- **WHEN** a visitor requests `/`
- **THEN** the page has the description meta, two `theme-color` metas with `prefers-color-scheme` light and dark media, and a viewport containing `viewport-fit=cover`

### Requirement: Home screen app
Maya SHALL serve a web app manifest at `/manifest.webmanifest` and link it from every page, so a phone can install Maya as a full screen app that opens at the Talk screen `/talk`.

#### Scenario: Manifest served
- **WHEN** a client requests `/manifest.webmanifest`
- **THEN** the response is JSON with name "Maya", short_name "Maya", start_url "/talk", display "standalone", a theme and background colour, and icons of 192 and 512 px plus a maskable 512 px icon

#### Scenario: iOS home screen tags
- **WHEN** a visitor requests `/`
- **THEN** the page links a 180 px `apple-touch-icon` and the manifest, and has `apple-mobile-web-app-capable`, a status bar style and the app title "Maya"

### Requirement: Link previews
Every page SHALL carry Open Graph and Twitter card tags whose image and URL are absolute and built from the configured site host, never a hard-coded host.

#### Scenario: Preview tags
- **WHEN** a visitor requests `/`
- **THEN** the page has `og:title`, `og:description`, `og:url` and `og:image` (a 1200 x 630 PNG), and `twitter:card` "summary_large_image", with URLs starting with the configured site url
