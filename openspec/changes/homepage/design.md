# Design

## Context

`/` is `live "/", TalkLive` in the `:browser` pipeline (router.ex). #49 (friends login, `Plug.BasicAuth`) and #85 (site metadata, manifest, site-wide noindex) are open; #84 (sticky HUD) is merged. The CSP is strict: `default-src 'self'`, so self-hosted video, poster and `.vtt` need no CSP change. ARCHITECTURE.md decision 7 says "`/` becomes the Talk screen"; this change supersedes it. See proposal.md for why.

## Goals / Non-Goals

**Goals:** a public static homepage that spends no API credit; the Talk screen unchanged except its path; honest copy (every number and claim backed by the repo).

**Non-Goals:** any interactivity on `/` beyond native video controls; a CMS or data-driven page; changing the voice loop.

## Decisions

1. **Plain controller page for `/`, not a LiveView.** A `PageController` with a HEEx template: no socket, no Conversation, nothing to supervise. Alternative (a LiveView) would open a socket per visitor for no gain.
2. **Two pipelines.** `/` (and later `/factory`) in `:browser`; `/talk` and `/fresh` in `:browser` plus the #49 login plug. Built on whatever plug #49 lands; if #49 protects every browser page, narrow it to `/talk` and `/fresh` as #49's latest comment (2026-11-15) says.
3. **Robots per page.** The root layout reads an assign (for example `:robots`) and renders `noindex, nofollow` unless the page sets it indexable; `/` sets it. `robots.txt` lists `Disallow: /talk` and `Disallow: /fresh` only. This replaces #85's site-wide noindex for `/` only.
4. **Manifest.** Change #85's `start_url` from `/` to `/talk`. If #85 lands a `site-metadata` capability that owns the manifest and robots requirements, move "Home screen app opens the Talk screen" and the robots requirements into a delta of it with `openspec-update-change` before building.
5. **Demo slot switches on the clip file.** The template checks once (module attribute with `@external_resource` on `priv/static/videos/maya-demo.mp4`) whether the clip exists. No clip: screenshots. Clip: `<video muted playsinline controls preload="metadata" poster=...>` with a `<track kind="captions">`. Native controls give tap to unmute without JS. Alternative (always ship a video element) would show an empty player.
6. **Screenshots are real.** Captured from the running Talk screen (local app with seed Progress, phone width about 390 px), saved as compressed PNG or JPEG under `priv/static/images/demo/`, each under 300 KB. No mock data.
7. **Voice loop diagram in HTML and CSS**: an ordered list styled as four connected steps, no image. The latency block shows `#latency-pending` until phone numbers from `mix maya.latency` are committed (README "How we know it works" or a later doc); a later PR swaps in the measured p50 and p95.
8. **Honest CI gate line.** `#promise-ci-gate` reads as planned until `.github/workflows/ci.yml` has a spoiler job (#40). A test reads `ci.yml` and asserts the wording matches, so the copy cannot drift.
9. **Footer art inline.** Paste `docs/assets/footer.svg` into a footer component as inline SVG (it keeps its `title`), reused by `/factory`.
10. **Hero ball.** Reuse the existing `pokeball-emerald` CSS from the trainer card; the ids are per page, so `#pokeball` exists once on each.

## Risks / Trade-offs

- [#49 or #85 change shape before this builds] → Build only after both merge; reconcile requirement names with `openspec-update-change` first.
- [Old bookmarks and the home screen icon point at `/`] → `/` stays useful (homepage with `#talk-link`); re-adding the home screen app picks up `/talk`.
- [Screenshots go stale as the Talk screen changes] → They are replaced by the clip; acceptable for a portfolio page.
- [Basic auth prompt on a home screen app] → iOS shows the login sheet once per session; same as #49 today.

## Migration Plan

One PR: routes, templates, tests moved from `/` to `/talk`, robots, manifest, ARCHITECTURE.md decision 7 note. Rollback is a revert of the PR. After deploy: `/` 200 without login, `/talk` 401 without login.

## Open Questions

- Which screenshots (empty Talk screen, a Roxanne Answer, speaking moment)? Builder picks 2 or 3 real ones; Abhishek can swap them.
