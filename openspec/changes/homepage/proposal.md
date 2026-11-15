# Proposal

## Why

Abhishek shares Maya with friends and as a portfolio piece. Today `/` is the Talk screen, which costs API credit on every Question and says nothing to a visitor who has no login. A public homepage at `/` lets visitors watch what Maya does, while the Talk screen moves to `/talk` behind the friends login (#49).

## What Changes

- **BREAKING** The Talk screen moves from `/` to `/talk`. `/talk` and `/fresh` sit behind the friends login from #49; `/`, `/health` and static assets stay public.
- `/` becomes a public homepage in the Calm Emerald identity (README hero, B3 Talk screen): a hero (Emerald ball over the tide, "Maya", "Maps, Answers, Yaps, Advice.", the Mudkip line), a demo slot, the voice loop, the spoiler promise and a footer.
- Demo slot: real B3 screenshots until Abhishek records the clip; then a self-hosted, muted MP4 under 5 MB with a poster, captions and a transcript. No YouTube, no iframes (CSP unchanged).
- The voice loop section shows hold, transcribe, agent with tools, speak; per-stage latency numbers only once measured (none yet: README says "pending the phone check").
- The spoiler promise: Facts only from Maya's own data (ADR-004), the Spoiler horizon at the Next gym, and the CI spoiler gate (#40), named as planned until its CI job exists.
- Search engines: `/` is indexable (this flips #85's site-wide noindex for `/` only); `/talk` keeps `noindex, nofollow`; `robots.txt` disallows `/talk` and `/fresh` only.
- The home screen app (#85 manifest) opens `/talk`.
- The Poké facts, the trainer card's Emerald ball and the badge case move with the Talk screen to `/talk`.
- Supersedes ARCHITECTURE.md decision 7 ("`/` becomes the Talk screen"); the build adds a note there.

Depends on: #84 (sticky HUD, merged), #85 (site metadata and manifest), #49 (friends login). Build after all three are merged.

Out of scope: a try-it demo mode (visitors never talk to Maya without the login), a tech stack section (link the Elixir and Phoenix explainer instead), the `/factory` page (change `factory-page`). New ideas go to PHASE_2.md.

GitHub Issue: added once it exists.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `landing-page`: becomes the public homepage at `/` (hero, demo, voice loop, spoiler promise, footer, indexable); the Talk screen requirements it held move to `talk-screen`.
- `talk-screen`: lives at `/talk` behind the friends login, carries the Poké facts, Emerald ball and badge case, is `noindex`, and is the home screen app's start page.

## Impact

- Router: `/` to a plain controller page, `TalkLive` to `/talk`, `/talk` and `/fresh` in the login pipeline from #49. Redirects after Start fresh go to `/talk`.
- Templates: new homepage template and footer; the Talk screen heading and links point at `/talk`.
- Static assets: screenshots under `priv/static/images/demo/`, later the clip under `priv/static/videos/`; footer art from `docs/assets/footer.svg`.
- `priv/static/robots.txt`, the root layout's robots meta per page, the manifest `start_url`.
- Tests that request `/` for the Talk screen move to `/talk`; the post-deploy smoke check keeps `/health`.
- ARCHITECTURE.md decision 7 note, README links if they name `/` as the Talk screen.
- No new dependency, service or host (settled-architecture checked: plain Phoenix pages and static files).
