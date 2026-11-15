Added: one shared login (HTTP Basic auth) in front of the Talk screen and Start fresh; health checks and static files stay public
Added: the release refuses to boot without `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD`
Changed: the post-deploy smoke check expects `/` to ask for the login (401)
