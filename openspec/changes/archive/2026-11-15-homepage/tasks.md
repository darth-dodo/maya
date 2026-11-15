# Tasks

## 1. Talk screen moves to /talk

- [x] 1.1 Route `TalkLive` at `/talk` (public, login deferred, see #49); `/fresh` redirects to `/talk`; move every Talk screen test from `/` to `/talk`; verify the talk-screen scenarios (including "Guest opens the Talk screen", "Start fresh returns to the Talk screen", "Public routes stay public") pass with `mix test`
- [x] 1.2 Talk heading, noindex meta on `/talk`, manifest `start_url` "/talk"; verify the "Heading on the Talk screen", "noindex on the Talk screen" and "Manifest start page" tests pass

## 2. Homepage at /

- [x] 2.1 Plain controller page at `/` with the hero (Emerald ball, heading, tagline, catchphrase, `#talk-link`) and no LiveView; verify the "Visitor opens the home page", "Hero parts", "Way in to the Talk screen" and "Static page" tests pass
- [x] 2.2 Demo slot with 2 or 3 real Talk screen screenshots under `priv/static/images/demo/` (each under 300 KB) and the clip branch (video, poster, captions, transcript, size test); verify "Screenshots before the clip" passes, and "Clip present" and "Size budget" pass against a temporary test fixture clip
- [x] 2.3 Voice loop section with the four steps and `#latency-pending`; verify "Four steps in order" and "No invented latency" pass
- [x] 2.4 Spoiler promise section with the `ci.yml` wording test; verify "Three promises", "Gate wording stays honest" and "Homepage stays spoiler-free" pass
- [x] 2.5 Footer component with inline footer art and the three links; verify "Footer links" passes
- [x] 2.6 Robots per page and `robots.txt` (`Disallow: /talk`, `Disallow: /fresh`); verify "No noindex on the home page", "robots.txt per route", "Only own assets", "Generator content is gone" and the CSP tests pass

## 3. Docs and checks

- [x] 3.1 ARCHITECTURE.md: note under decision 7 that this change superseded it (`/` is the homepage, Talk is at `/talk`); README links that call `/` the Talk screen updated; landing-page and talk-screen Purpose lines updated after archive; verify with `grep -n '/talk' ARCHITECTURE.md README.md`
- [ ] 3.2 Phone check after deploy: `/` and `/talk` load without a login, the home screen app opens `/talk`; screenshots in the PR

## Workflow follow-up

- Archive the change with `openspec-archive-change` in the same PR.
- Changelog fragment `changelog.d/<branch-with-dashes>.md`.
