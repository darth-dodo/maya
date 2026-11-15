# Spec Delta

## MODIFIED Requirements

### Requirement: Home screen app
Maya SHALL serve a web app manifest at `/manifest.webmanifest` and link it from every page, so a phone can install Maya as a full screen app that opens at the Talk screen `/talk`.

#### Scenario: Manifest served
- **WHEN** a client requests `/manifest.webmanifest`
- **THEN** the response is JSON with name "Maya", short_name "Maya", start_url "/talk", display "standalone", a theme and background colour, and icons of 192 and 512 px plus a maskable 512 px icon

#### Scenario: iOS home screen tags
- **WHEN** a visitor requests `/`
- **THEN** the page links a 180 px `apple-touch-icon` and the manifest, and has `apple-mobile-web-app-capable`, a status bar style and the app title "Maya"

## REMOVED Requirements

### Requirement: Hidden from search until login
**Reason**: `/` is now a public homepage meant to be found. The login is deferred (#49), so robots are set per route instead of waiting for it.
**Migration**: Robots are per route: `landing-page` "Homepage is indexable" (no noindex on `/`, `robots.txt` disallows only `/talk` and `/fresh`) and `talk-screen` "Talk screen kept out of search engines" (noindex on `/talk`).
