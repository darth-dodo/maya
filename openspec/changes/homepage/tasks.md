# Tasks

## 1. Talk screen moves to /talk

- [ ] 1.1 Route `TalkLive` at `/talk` and `/fresh` behind the #49 login plug; `/fresh` redirects to `/talk`; move every Talk screen test from `/` to `/talk`; verify the talk-screen scenarios (including "No login", "Friend signed in", "Start fresh needs the login", "Public routes stay public") pass with `mix test`
- [ ] 1.2 Talk heading, noindex meta on `/talk`, manifest `start_url` "/talk"; verify the "Heading on the Talk screen", "noindex on the Talk screen" and "Manifest start page" tests pass

## 2. Homepage at /

- [ ] 2.1 Plain controller page at `/` with the hero (Emerald ball, heading, tagline, catchphrase, `#talk-link`) and no LiveView; verify the "Visitor opens the home page", "Hero parts", "Way in for friends" and "Static page" tests pass
- [ ] 2.2 Demo slot with 2 or 3 real Talk screen screenshots under `priv/static/images/demo/` (each under 300 KB) and the clip branch (video, poster, captions, transcript, size test); verify "Screenshots before the clip" passes, and "Clip present" and "Size budget" pass against a temporary test fixture clip
- [ ] 2.3 Voice loop section with the four steps and `#latency-pending`; verify "Four steps in order" and "No invented latency" pass
- [ ] 2.4 Spoiler promise section with the `ci.yml` wording test; verify "Three promises", "Gate wording stays honest" and "Homepage stays spoiler-free" pass
- [ ] 2.5 Footer component with inline footer art and the three links; verify "Footer links" passes
- [ ] 2.6 Robots per page and `robots.txt` (`Disallow: /talk`, `Disallow: /fresh`); verify "No noindex on the home page", "robots.txt per route", "Only own assets", "Generator content is gone" and the CSP tests pass

## 3. Docs and checks

- [ ] 3.1 ARCHITECTURE.md: note under decision 7 that this change superseded it (`/` is the homepage, Talk is at `/talk`); README links that call `/` the Talk screen updated; landing-page and talk-screen Purpose lines updated after archive; verify with `grep -n '/talk' ARCHITECTURE.md README.md`
- [ ] 3.2 Phone check after deploy: `/` loads without a login, `/talk` asks for it, the home screen app opens `/talk`; screenshots in the PR

## Workflow follow-up

- Archive the change with `openspec-archive-change` in the same PR.
- Changelog fragment `changelog.d/<branch-with-dashes>.md`.
