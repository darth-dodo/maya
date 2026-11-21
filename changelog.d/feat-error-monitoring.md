Added: server side error monitoring with Sentry (free Developer plan, EU), off unless `SENTRY_DSN` is set: turn Task, Conversation, LiveView and controller crashes and `Logger.error` lines arrive with stack, `release` (the Render commit), `environment` and a `stage` tag
Added: `Logger.warning` lines ride on the next error as breadcrumbs, never their own events
Added: a `before_send` allow-list drops request data, cookies, headers, user, extra, frame vars and any string that quotes data or runs past 120 characters, so no Question, Answer or guest id leaves the app
