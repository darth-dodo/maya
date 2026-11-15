Added: `POST /health/ask`, one text Question to the agent gated by the `SMOKE_TOKEN` header token (404 when unset); the hourly post-deploy smoke check asks it and opens a `bug` Issue on a failed or empty Answer (factory experiment E3)
Added: `escaped_defects` column in `factory:retro` and `factory:improve`
Changed: Factory experiment E2 (Hex mirror fallback) kept; LESSONS.md gains the lessons from #52 to #60
