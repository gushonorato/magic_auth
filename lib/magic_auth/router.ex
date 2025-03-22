defmodule MagicAuth.Router do
  @moduledoc """
  Responsible for defining and managing MagicAuth authentication routes.

  This module provides macros to configure authentication routes in Phoenix applications,
  allowing customization of login and password paths.

  ## Usage

  To use it, add `use MagicAuth.Router` to your router module:

  ```elixir
  defmodule MyApp.Router do
    use Phoenix.Router
    use MagicAuth.Router

    # Default configuration
    magic_auth()

    # Or with custom configuration
    magic_auth("/auth", log_in: "/entrar", password: "/senha", log_out: "/sair")
  end
  ```

  For more information about path customization, see the `magic_auth/2` macro.

  ## Introspection Functions

  The following functions are used internally to generate and manage authentication routes:

  - `__magic_auth__(:scope)` - Returns the configured base path
  - `__magic_auth__(:log_in, query)` - Returns the login path with optional query parameters
  - `__magic_auth__(:password, query)` - Returns the password path with optional query parameters
  - `__magic_auth__(:verify, query)` - Returns the verify path with optional query parameters
  - `__magic_auth__(:log_out, query)` - Returns the log out path with optional query parameters
  - `__magic_auth__(:signed_in, query)` - Returns the signed in path with optional query parameters

  The `query` parameter is an optional map that allows adding query parameters to the generated URLs.

  ### Example
  ```elixir
    __magic_auth__(:log_in, %{foo: "bar", foo: "bar"})
    # Returns: "/sessions/login?foo=bar
  ```
  """
  defmacro __using__(_opts) do
    quote do
      import MagicAuth.Router
      import MagicAuth, only: [require_authenticated: 2, redirect_if_authenticated: 2, fetch_magic_auth_session: 2]
    end
  end

  @doc """
  Macro to configure MagicAuth authentication routes.

  ## Parameters

    * `scope` - Base path for authentication routes. Default: "/sessions"
    * `opts` - List of options to customize paths:
      * `:log_in` - Path for login page. Default: "/log_in"
      * `:password` - Path for password page. Default: "/password"
      * `:verify` - Path for verify controller. Default: "/verify"
      * `:log_out` - Path for log out controller. Default: "/log_out"
      * `:signed_in` - Path for signed in page. Default: "/"

  ## Default configuration

  ```elixir
  magic_auth()
  ```

  Generates the following default routes:
  - /sessions/log_in
  - /sessions/password
  - /sessions/verify
  - /sessions/log_out

  ## Custom configuration

  ```
  magic_auth("/auth", log_in: "/entrar", password: "/senha", verify: "/verificar", log_out: "/sair")
  ```

  Generates the following custom routes:
  - /auth/entrar
  - /auth/senha
  - /auth/verificar
  - /auth/sair


  ## Customizing the default sign in path

  The default sign in path can be customized by passing the `:signed_in` parameter in the `magic_auth` macro call.
  This allows developers to define a custom path for the sign in page after authentication.

  Note that Magic Auth will redirect users to their requested page. If no specific page is requested, users will
  be redirected to the route configured in the `signed_in` option. For example, if a user accesses the application
  by visiting the `/sessions/log_in` page, they will be redirected to the `signed_in` route after the successful
  log in.

  Example:
  ```
  magic_auth("/auth", signed_in: "/dashboard")
  ```
  This will generate a custom sign in path to `/dashboard` instead of the default `/`.
  """
  defmacro magic_auth(scope \\ "/sessions", opts \\ []) do
    log_in = Keyword.get(opts, :log_in, "/log_in")
    password = Keyword.get(opts, :password, "/password")
    verify = Keyword.get(opts, :verify, "/verify")
    log_out = Keyword.get(opts, :log_out, "/log_out")
    signed_in = Keyword.get(opts, :signed_in, "/")

    quote bind_quoted: [
            scope: scope,
            log_in: log_in,
            password: password,
            verify: verify,
            log_out: log_out,
            signed_in: signed_in
          ] do
      def __magic_auth__(:scope), do: unquote(scope)

      def __magic_auth__(path, query \\ %{})

      def __magic_auth__(:log_in, query) do
        concat_query(__magic_auth__(:scope) <> unquote(log_in), query)
      end

      def __magic_auth__(:password, query) do
        concat_query(__magic_auth__(:scope) <> unquote(password), query)
      end

      def __magic_auth__(:verify, query) do
        concat_query(__magic_auth__(:scope) <> unquote(verify), query)
      end

      def __magic_auth__(:log_out, query) do
        concat_query(__magic_auth__(:scope) <> unquote(log_out), query)
      end

      def __magic_auth__(:signed_in, query), do: concat_query(unquote(signed_in), query)

      defp concat_query(path, query) when query == %{}, do: path
      defp concat_query(path, query), do: path <> "?" <> URI.encode_query(query)

      scope scope, MagicAuth do
        pipe_through [:browser, :require_authenticated]

        delete log_out, SessionController, :log_out
        delete log_out <> "/all", SessionController, :log_out_all
        get log_out <> "/all/get", SessionController, :log_out_all
      end

      scope scope, MagicAuth do
        pipe_through [:browser, :redirect_if_authenticated]

        live_session :redirect_if_authenticated,
          on_mount: [{MagicAuth, :redirect_if_authenticated}] do
          live log_in, LoginLive
          live password, PasswordLive
        end

        get verify, SessionController, :verify
      end
    end
  end
end
