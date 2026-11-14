## Purpose

Limits what a browser may load or run on Maya's pages, so injected markup cannot pull in third-party scripts or frame the site, while Maya's own assets keep working.

## ADDED Requirements

### Requirement: Content Security Policy on browser pages
Every page served through the browser pipeline SHALL send a `content-security-policy` header that allows scripts, styles, images, fonts and connections only from Maya's own origin, allows inline scripts only by hash, and forbids plugins and being framed.

#### Scenario: Header present
- **WHEN** a visitor requests `/`
- **THEN** the response has a `content-security-policy` header
- **AND** it contains `default-src 'self'`, `object-src 'none'` and `frame-ancestors 'none'`

#### Scenario: Inline scripts are allowed only by hash
- **WHEN** a visitor requests `/`
- **THEN** every inline `script` element on the page has a matching `'sha256-...'` source in the policy's `script-src`
- **AND** `script-src` does not contain `'unsafe-inline'` or `'unsafe-eval'`

#### Scenario: No third-party origins
- **WHEN** a visitor requests `/`
- **THEN** the policy names no host other than `'self'`, `data:` for images, and script hashes
