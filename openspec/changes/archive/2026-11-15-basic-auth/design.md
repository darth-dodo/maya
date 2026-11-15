## Context

The router has one `:browser` pipeline for `live "/", TalkLive` and `post "/fresh"`; health and smoke routes sit in a scope with no pipeline. Static files are served by `Plug.Static` in the endpoint, before the router. The homepage change (#90) moves Talk to `/talk` and keeps `/` public.

## Goals / Non-Goals

**Goals:** one login in front of what spends API credit; a pipeline #91 can reuse by moving one route; fail safe at boot.

**Non-Goals:** accounts, sessions of our own, logout, moving routes.

## Decisions

1. **`Plug.BasicAuth.basic_auth/2` in a `:require_login` pipeline.** A private router function reads `Application.fetch_env!(:maya, :basic_auth)` per request and calls `basic_auth(conn, username: ..., password: ...)`, which compares with `Plug.Crypto.secure_compare/2` and sends the 401 with `www-authenticate` (https://hexdocs.pm/plug/Plug.BasicAuth.html). The Talk scope pipes through `[:browser, :require_login]`. Alternative (a custom plug) adds code for nothing.
2. **Env read only in `config/runtime.exs`** (LESSONS.md). Prod raises when either variable is missing or empty, like the `SECRET_KEY_BASE` guard; the message names the variable, never a value. Dev reads the variables with a visible dev-only default; test sets fixed values in `config/test.exs`.
3. **LiveView socket rides the session.** The socket only mounts from a page that already passed the login, and LiveView verifies the signed session on connect (https://hexdocs.pm/phoenix_live_view/security-model.html). Per that guide, the HTTP check is enough when nothing about the login changes during the socket's life; here there is one shared login and no logout.
4. **ConnCase signs in by default** so existing tests keep passing; login tests remove the header.
5. **CI docker job** gets test values so the release boots.

## Risks / Trade-offs

- [A deploy without the env vars fails] → intended; Render keeps the last good version. Abhishek sets both before merging.
- [Home screen app on iOS asks for the login] → once per session, accepted in #90's design.
- [Basic auth over plain HTTP leaks the password] → Render serves HTTPS only.

## Migration Plan

Set `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD` in Render, merge, check `/` asks for the login and `/health` answers 200. Rollback: revert the PR.

## Open Questions

None.
