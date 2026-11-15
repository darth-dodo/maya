# Design

## Context

`/` is `live "/", TalkLive` in the `:browser` pipeline (router.ex). #85 (site metadata, manifest, site-wide noindex) and #84 (sticky HUD) are merged. Login deferred, see #49: Abhishek decided on 2026-11-15 that Guests use Maya without a login for now, so #49 is parked. The CSP is strict: `default-src 'self'`, so self-hosted video, poster and `.vtt` need no CSP change. ARCHITECTURE.md decision 7 says "`/` becomes the Talk screen"; this change supersedes it. See proposal.md for why.

## Goals / Non-Goals

**Goals:** a public static homepage that spends no API credit; the Talk screen unchanged except its path; honest copy (every number and claim backed by the repo).

**Non-Goals:** any interactivity on `/` beyond native video controls; a CMS or data-driven page; changing the voice loop.

## Decisions

1. **Plain controller page for `/`, not a LiveView.** A `PageController` with a HEEx template: no socket, no Conversation, nothing to supervise. Alternative (a LiveView) would open a socket per visitor for no gain.
2. **One pipeline for now.** `/`, `/talk` and `/fresh` all sit in `:browser`. Login deferred, see #49: when it lands, it wraps `/talk` and `/fresh` only, and `/` stays public.
3. **Robots per page.** The root layout reads an assign (for example `:robots`) and renders `noindex, nofollow` unless the page sets it indexable; `/` sets it. `robots.txt` lists `Disallow: /talk` and `Disallow: /fresh` only. This replaces #85's site-wide noindex for `/` only.
4. **Manifest.** Change #85's `start_url` from `/` to `/talk`. If #85 lands a `site-metadata` capability that owns the manifest and robots requirements, move "Home screen app opens the Talk screen" and the robots requirements into a delta of it with `openspec-update-change` before building.
5. **Demo slot switches on the clip file.** The template checks once (module attribute with `@external_resource` on `priv/static/videos/maya-demo.mp4`) whether the clip exists. No clip: screenshots. Clip: `<video muted playsinline controls preload="metadata" poster=...>` with a `<track kind="captions">`. Native controls give tap to unmute without JS. Alternative (always ship a video element) would show an empty player.
6. **Screenshots are real.** Captured from the running Talk screen (local app with seed Progress, phone width about 390 px), saved as compressed PNG or JPEG under `priv/static/images/demo/`, each under 300 KB. No mock data.
7. **Voice loop diagram in HTML and CSS**: an ordered list styled as four connected steps, no image. The latency block shows `#latency-pending` until phone numbers from `mix maya.latency` are committed (README "How we know it works" or a later doc); a later PR swaps in the measured p50 and p95.
8. **Honest CI gate line.** `#promise-ci-gate` reads as planned until `.github/workflows/ci.yml` has a spoiler job (#40). A test reads `ci.yml` and asserts the wording matches, so the copy cannot drift.
9. **Footer art inline.** Paste `docs/assets/footer.svg` into a footer component as inline SVG (it keeps its `title`), reused by `/factory`.
10. **Hero ball.** Reuse the existing `pokeball-emerald` CSS from the trainer card; the ids are per page, so `#pokeball` exists once on each.

## Risks / Trade-offs

- [#85 changed shape before this built] → Its `site-metadata` requirements are reconciled in a delta of this change (decision 4).
- [Old bookmarks and the home screen icon point at `/`] → `/` stays useful (homepage with `#talk-link`); re-adding the home screen app picks up `/talk`.
- [Screenshots go stale as the Talk screen changes] → They are replaced by the clip; acceptable for a portfolio page.
- [The Talk screen is public and spends API credit per Question] → Accepted by Abhishek for now (login deferred, see #49); `/talk` is `noindex` and disallowed in `robots.txt`, so search engines do not send traffic there.

## Migration Plan

One PR: routes, templates, tests moved from `/` to `/talk`, robots, manifest, ARCHITECTURE.md decision 7 note. Rollback is a revert of the PR. After deploy: `/` and `/talk` both answer 200.

## Open Questions

- Which screenshots (empty Talk screen, a Roxanne Answer, speaking moment)? Builder picks 2 or 3 real ones; Abhishek can swap them.
