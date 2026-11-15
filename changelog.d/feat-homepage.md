Added: Public homepage at `/`: hero with the Emerald ball over the tide, two real Talk screen screenshots, the voice loop (latency pending the phone check), the spoiler promise and a footer; indexable by search engines
Changed: The Talk screen moves from `/` to `/talk` (public, `noindex`; login deferred, see #49); Start fresh returns to `/talk`; the home screen app opens `/talk`
Changed: `robots.txt` disallows only `/talk` and `/fresh`; the post-deploy smoke check checks `/`, `/talk` and `/health`
