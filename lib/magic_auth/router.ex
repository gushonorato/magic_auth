defmodule MagicAuth.Router do
  defmacro __using__(_opts) do
    quote do
      import MagicAuth.Router
    end
  end

  defmacro magic_auth(scope \\ "/sessions", opts \\ []) do
    login = Keyword.get(opts, :login, "/login")
    password = Keyword.get(opts, :password, "/password")

    quote bind_quoted: [scope: scope, login: login, password: password] do
      def __magic_auth__(:scope), do: unquote(scope)

      def __magic_auth__(path, query \\ %{})

      def __magic_auth__(:login, query) do
        concat_query(__magic_auth__(:scope) <> unquote(login), query)
      end

      def __magic_auth__(:password, query) do
        concat_query(__magic_auth__(:scope) <> unquote(password), query)
      end

      defp concat_query(path, query) when query == %{}, do: path
      defp concat_query(path, query), do: path <> "?" <> URI.encode_query(query)

      scope scope, MagicAuth do
        pipe_through :browser

        live login, LoginLive, :magic_auth_login
        live password, PasswordLive, :magic_auth_password
      end
    end
  end
end
