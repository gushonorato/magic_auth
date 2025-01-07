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
    magic_auth("/auth", login: "/entrar", password: "/senha")
  end
  ```

  ## Generated Routes

  By default, the module generates the following routes:

  - `/sessions/login` - Login page
  - `/sessions/password` - Password page
  - `/sessions/verify` - Verify controller

  For more information about path customization, see the `magic_auth/2` macro.

  ## Introspection Functions

  The following functions are used internally to generate and manage authentication routes:

  - `__magic_auth__(:scope)` - Returns the configured base path
  - `__magic_auth__(:login, query)` - Returns the login path with optional query parameters
  - `__magic_auth__(:password, query)` - Returns the password path with optional query parameters
  - `__magic_auth__(:verify, query)` - Returns the verify path with optional query parameters
  - `__magic_auth__(:signed_in, query)` - Returns the signed in path with optional query parameters

  The `query` parameter is an optional map that allows adding query parameters to the generated URLs.

  ### Example

    __magic_auth__(:login, %{foo: "bar", foo: "bar"})
    # Returns: "/sessions/login?foo=bar
  """
  defmacro __using__(_opts) do
    quote do
      import MagicAuth.Router
    end
  end

  @doc """
  Macro to configure MagicAuth authentication routes.

  ## Parameters

    * `scope` - Base path for authentication routes. Default: "/sessions"
    * `opts` - List of options to customize paths:
      * `:login` - Path for login page. Default: "/login"
      * `:password` - Path for password page. Default: "/password"
      * `:verify` - Path for verify controller. Default: "/verify"
      * `:signed_in` - Path for signed in page. Default: "/"

  ## Example

      # Default configuration
      magic_auth()
      # Generates:
      # /sessions/login
      # /sessions/password
      # /sessions/verify

      # Custom configuration
      magic_auth("/auth", login: "/entrar", password: "/senha", verify: "/verificar")
      # Generates:
      # /auth/entrar
      # /auth/senha
      # /auth/verificar
  """
  defmacro magic_auth(scope \\ "/sessions", opts \\ []) do
    login = Keyword.get(opts, :login, "/login")
    password = Keyword.get(opts, :password, "/password")
    verify = Keyword.get(opts, :verify, "/verify")
    signed_in = Keyword.get(opts, :signed_in, "/")

    quote bind_quoted: [scope: scope, login: login, password: password, verify: verify, signed_in: signed_in] do
      def __magic_auth__(:scope), do: unquote(scope)

      def __magic_auth__(path, query \\ %{})

      def __magic_auth__(:login, query) do
        concat_query(__magic_auth__(:scope) <> unquote(login), query)
      end

      def __magic_auth__(:password, query) do
        concat_query(__magic_auth__(:scope) <> unquote(password), query)
      end

      def __magic_auth__(:verify, query) do
        concat_query(__magic_auth__(:scope) <> unquote(verify), query)
      end

      def __magic_auth__(:signed_in, query), do: concat_query(unquote(signed_in), query)

      defp concat_query(path, query) when query == %{}, do: path
      defp concat_query(path, query), do: path <> "?" <> URI.encode_query(query)

      scope scope, MagicAuth do
        pipe_through :browser

        live login, LoginLive
        live password, PasswordLive
        get verify, VerifyController, :verify
      end
    end
  end
end
