defmodule MagicAuth.Config do
  @moduledoc """
  Configuration module for MagicAuth.

  This module provides functions to access configuration values for the MagicAuth library.
  It handles default values and required configurations.

  ## Configuration Options

  - `:repo` - (required) The Ecto repository module used by your application.
  - `:router` - (required) Your application's router module.
  - `:callbacks` - (required) Module implementing MagicAuth callback functions.
  - `:endpoint` - (required) Your Phoenix application's endpoint module.
  - `:remember_me_cookie` - (required) Name of the cookie used for "remember me" functionality.
  - `:get_user` - required only if you want to use the `current_user` assign in your LiveView / Controllers.
      If you are returning `{:allow, user_id}` from the `log_in_requested/1` callback, you need to
      configure the `get_user` function to retrieve the user.
  - `:repo_opts` - (optional, default: `[magic_auth: true]`) Options passed to repository calls.
  Can be a keyword list or a function that returns options. Passing a function is useful to pass
  options that are dependent on the current environment. For example, you can pass a function that
  returns the current tenant prefix: `fn -> [prefix: MyApp.Repo.get_org_id()] end`.
  - `:one_time_password_length` - (optional, default: `6`) Length of generated one-time passwords.
  - `:one_time_password_expiration` - (optional, default: `10`) Expiration time in minutes for one-time passwords.
  - `:remember_me` - (optional, default: `true`) Whether to enable "remember me" functionality.
  - `:session_validity_in_days` - (optional, default: `60`) How long sessions remain valid.
  - `:session_expiration` - (optional, default: `:log_in`) What the session validity is counted from. With `:log_in`,
  sessions expire `session_validity_in_days` after the log in. With `:inactivity`, they expire
  `session_validity_in_days` after the last request, and the "remember me" cookie is renewed as the user keeps using
  the application.
  - `:session_activity_update_interval` - (optional, default: `5`) Interval in minutes between updates of the session
  activity (`last_active_at`, `last_ip` and `user_agent`). The activity is updated on the first request after the
  interval, so it doesn't write to the database on every request.
  - `:delete_expired_sessions` - (optional, default: `false`) Whether to periodically delete the expired sessions. When
  enabled, `MagicAuth.children/0` includes `MagicAuth.ExpiredSessionsCleaner`. Don't enable it when using
  multi-tenancy with query prefixes; call `MagicAuth.delete_expired_sessions/0` for each tenant instead.
  - `:client_ip_header` - (optional, default: `nil`) Request header with the client's IP address, stored in the
  session's `last_ip`. Set it when the application runs behind a proxy, such as `"fly-client-ip"` on Fly.io. When not
  set, `conn.remote_ip` is used. See the [Sessions guide](sessions.md#client-ip-address-behind-a-proxy).
  - `:enable_rate_limit` - (optional, default: `true`) Whether to enable rate limiting for authentication attempts.

  ## Configuration Example

  In your `config/config.exs` file:

  ```elixir
  config :magic_auth,
    repo: MyApp.Repo,
    router: MyAppWeb.Router,
    callbacks: MyAppWeb.MagicAuthCallbacks,
    endpoint: MyAppWeb.Endpoint,
    remember_me_cookie: "magic_auth_remember_me",
    get_user: &MyApp.Accounts.get_user/1,
    # Optional configurations
    one_time_password_length: 6,
    one_time_password_expiration: 10,
    remember_me: true,
    session_validity_in_days: 60,
    session_expiration: :log_in,
    session_activity_update_interval: 5,
    delete_expired_sessions: true,
    client_ip_header: "fly-client-ip",
    enable_rate_limit: true,
    repo_opts: fn -> [magic_auth: true] end
  ```
  """

  def one_time_password_length, do: Application.get_env(:magic_auth, :one_time_password_length, 6)
  def one_time_password_expiration, do: Application.get_env(:magic_auth, :one_time_password_expiration, 10)

  def repo_module do
    Application.fetch_env!(:magic_auth, :repo)
  end

  def repo_opts do
    case Application.get_env(:magic_auth, :repo_opts, magic_auth: true) do
      opts when is_list(opts) -> opts
      opts when is_function(opts) -> opts.()
    end
  end

  def callback_module do
    Application.fetch_env!(:magic_auth, :callbacks)
  end

  def router() do
    Application.fetch_env!(:magic_auth, :router)
  end

  def remember_me do
    Application.get_env(:magic_auth, :remember_me, true)
  end

  def remember_me_cookie do
    Application.fetch_env!(:magic_auth, :remember_me_cookie)
  end

  def session_validity_in_days do
    Application.get_env(:magic_auth, :session_validity_in_days, 60)
  end

  def session_expiration do
    Application.get_env(:magic_auth, :session_expiration, :log_in)
  end

  def session_activity_update_interval do
    Application.get_env(:magic_auth, :session_activity_update_interval, 5)
  end

  def delete_expired_sessions? do
    Application.get_env(:magic_auth, :delete_expired_sessions, false)
  end

  def client_ip_header do
    Application.get_env(:magic_auth, :client_ip_header)
  end

  def endpoint() do
    Application.fetch_env!(:magic_auth, :endpoint)
  end

  def rate_limit_enabled? do
    Application.get_env(:magic_auth, :enable_rate_limit, true)
  end

  def get_user() do
    Application.fetch_env!(:magic_auth, :get_user)
  end
end
