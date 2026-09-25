# Sessions

Magic Auth creates a session in the database for every log in. This guide explains the information stored in each
session, how sessions expire and how to delete expired sessions.

## Session activity

Besides the email and the user ID, each `MagicAuth.Session` stores:

- `last_active_at` - Time of the last request made with the session.
- `last_ip` - IP address of the last request.
- `user_agent` - User agent of the last request, truncated to 512 characters.

They are set on log in and updated by `MagicAuth.fetch_magic_auth_session/2`. To not write to the database on every
request, they are updated on the first request after the interval configured in `:session_activity_update_interval`
(default: 5 minutes):

```elixir
config :magic_auth,
  session_activity_update_interval: 5
```

The current session is available in `conn.assigns.current_session` and `socket.assigns.current_session`. You can use
this information, for example, to show the user the devices where they are logged in.

Requests handled by a connected LiveView go through the WebSocket, not through `fetch_magic_auth_session/2`, so they
don't update the activity. It's updated again on the next page load.

The user agent is stored as sent by the browser (e.g.
`Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ...`). To show something like "Chrome on macOS",
parse it with a library such as [ua_parser](https://hex.pm/packages/ua_parser).

## Client IP address behind a proxy

When your application runs behind a proxy or load balancer, `conn.remote_ip` is the IP address of the proxy, not of
the user. The proxy sends the user's IP address in a request header, which you can configure in
`:client_ip_header`:

```elixir
config :magic_auth,
  client_ip_header: "fly-client-ip"
```

The header must contain a single IP address. If the header is missing or its value isn't an IP address, Magic Auth
uses `conn.remote_ip`.

Only configure a header that your proxy always sets, overwriting the value sent by the client. Otherwise, anyone can
send the header with any IP address. For the same reason, don't configure it when the application isn't behind a
proxy.

Headers for some common setups:

| Setup | Header |
| --- | --- |
| [Fly.io](https://fly.io/docs/networking/request-headers/) | `fly-client-ip` |
| [Cloudflare](https://developers.cloudflare.com/fundamentals/reference/http-headers/) | `cf-connecting-ip` |
| Nginx with `proxy_set_header X-Real-IP $remote_addr;` | `x-real-ip` |

When there is more than one proxy, use the header set by the first one the request goes through. For example, with
Cloudflare in front of Fly.io, `fly-client-ip` contains the IP address of Cloudflare, so use `cf-connecting-ip`.

### X-Forwarded-For

Some platforms, such as Heroku, only send the `x-forwarded-for` header. It contains a list of IP addresses, and the
client can add fake addresses to the beginning of the list, so the right address depends on how many proxies are in
front of your application. Magic Auth doesn't parse it.

In this case, use a library such as [remote_ip](https://hex.pm/packages/remote_ip) in your endpoint, before the
router, and don't configure `:client_ip_header`:

```elixir
# lib/my_app_web/endpoint.ex
plug RemoteIp
plug MyAppWeb.Router
```

`RemoteIp` updates `conn.remote_ip`, which also fixes the IP address in your logs and in other plugs.

## Expiration

Sessions are valid for the number of days configured in `:session_validity_in_days` (default: 60). The
`:session_expiration` configuration defines what the validity is counted from:

- `:log_in` (default) - Sessions expire `session_validity_in_days` after the log in, even if the user keeps using the
  application.
- `:inactivity` - Sessions expire `session_validity_in_days` after the last activity. The "remember me" cookie is
  renewed when the activity is updated, so it doesn't expire in the browser while the session is valid.

```elixir
config :magic_auth,
  session_validity_in_days: 30,
  session_expiration: :inactivity
```

## Deleting expired sessions

Expired sessions can no longer be used to log in, but they stay in the database, along with the IP address and the
user agent, until they are deleted with `MagicAuth.delete_expired_sessions/0`. It also disconnects the LiveViews
connected with the deleted sessions.

To delete them automatically, enable `:delete_expired_sessions`:

```elixir
config :magic_auth,
  delete_expired_sessions: true
```

`MagicAuth.children/0` then includes `MagicAuth.ExpiredSessionsCleaner`, a process that deletes the expired sessions
when your application starts and then once a day. The installer already adds `MagicAuth.children/0` to your
`application.ex`. If the deletion fails, for example while the database is unavailable, the error is logged and the
process tries again on the next day.

You can also schedule the deletion yourself. For example, with an [Oban](https://hexdocs.pm/oban) cron job that runs
every day:

```elixir
defmodule MyApp.Workers.DeleteExpiredSessions do
  use Oban.Worker

  @impl Oban.Worker
  def perform(_job) do
    MagicAuth.delete_expired_sessions()
    :ok
  end
end
```

```elixir
config :my_app, Oban,
  plugins: [
    {Oban.Plugins.Cron, crontab: [{"0 3 * * *", MyApp.Workers.DeleteExpiredSessions}]}
  ]
```

When using [multi-tenancy with query prefixes](multi_tenancy.md), `delete_expired_sessions/0` uses the prefix returned
by `:repo_opts`, so don't enable `:delete_expired_sessions`. Schedule the deletion yourself and call
`delete_expired_sessions/0` once for each tenant.
