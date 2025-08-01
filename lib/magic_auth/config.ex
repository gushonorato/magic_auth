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
    enable_rate_limit: true,
    repo_opts: fn -> [magic_auth: true] end
  ```

  ## Process-Based Configuration

  This module also supports process-based configuration via ProcessTree.
  When a config map is stored in the process dictionary with key `:magic_auth_config`,
  it will be used instead of the Application configuration. This allows for
  per-request or per-context configuration.

  For LiveView compatibility, use the same function in both a plug and an on_mount callback:

  ```elixir
  defmodule MyApp.MagicAuthConfigPlug do
    def call(conn, _opts) do
      set_magic_auth_config()
      conn
    end

    def set_magic_auth_config do
      Process.put(:magic_auth_config, %{one_time_password_length: 6})
    end

    def on_mount(:set_magic_auth_config, _params, _session, socket) do
      set_magic_auth_config()
      {:cont, socket}
    end
  end
  ```
  """

  def one_time_password_length do
    case get_config_value(:one_time_password_length) do
      nil -> Application.get_env(:magic_auth, :one_time_password_length, 6)
      value -> value
    end
  end

  def one_time_password_expiration do
    case get_config_value(:one_time_password_expiration) do
      nil -> Application.get_env(:magic_auth, :one_time_password_expiration, 10)
      value -> value
    end
  end

  def repo_module do
    get_config_value(:repo) || Application.fetch_env!(:magic_auth, :repo)
  end

  def repo_opts do
    case get_config_value(:repo_opts) || Application.get_env(:magic_auth, :repo_opts, magic_auth: true) do
      opts when is_list(opts) -> opts
      opts when is_function(opts) -> opts.()
    end
  end

  def callback_module do
    get_config_value(:callbacks) || Application.fetch_env!(:magic_auth, :callbacks)
  end

  def router() do
    get_config_value(:router) || Application.fetch_env!(:magic_auth, :router)
  end

  def remember_me do
    case get_config_value(:remember_me) do
      nil -> Application.get_env(:magic_auth, :remember_me, true)
      value -> value
    end
  end

  def remember_me_cookie do
    get_config_value(:remember_me_cookie) || Application.fetch_env!(:magic_auth, :remember_me_cookie)
  end

  def session_validity_in_days do
    case get_config_value(:session_validity_in_days) do
      nil -> Application.get_env(:magic_auth, :session_validity_in_days, 60)
      value -> value
    end
  end

  def endpoint() do
    get_config_value(:endpoint) || Application.fetch_env!(:magic_auth, :endpoint)
  end

  def rate_limit_enabled? do
    case get_config_value(:enable_rate_limit) do
      nil -> Application.get_env(:magic_auth, :enable_rate_limit, true)
      value -> value
    end
  end

  def get_user() do
    get_config_value(:get_user) || Application.fetch_env!(:magic_auth, :get_user)
  end

  # Private helper functions

  defp get_config_value(key) do
    case ProcessTree.get(:magic_auth_config) do
      config when is_map(config) -> Map.get(config, key)
      _ -> nil
    end
  end
end
