# Tasks

## 1. Art

- [x] 1.1 `priv/static/images/maya-icon.svg`: original Emerald ball on a tide green rounded square; verify it reads at 16 px in a browser screenshot
- [x] 1.2 PNGs (16, 32, 180, 192, 512, maskable 512, 1200 x 630 og-image) and a new `favicon.ico`; verify each size with `sips`

## 2. Tests first

- [x] 2.1 ConnCase tests for the head tags, manifest and robots.txt (DB tests run in CI only: local Docker was hung; the rendered head and static responses were checked with a `mix run` script against the endpoint)

## 3. Build

- [x] 3.1 Root layout tags with absolute URLs from the endpoint url; manifest and robots.txt in `priv/static`; `static_paths` extended; CSP unchanged (`manifest-src` falls back to `default-src 'self'`, icons are `img-src 'self'`)

## 4. Verify

- [x] 4.1 All gates (`factory:test`), each exit code checked; `mix test` in CI
- [x] 4.2 Phone check written in the PR for Abhishek: Add to Home Screen on iPhone shows the Emerald icon and opens full screen at the Talk screen
