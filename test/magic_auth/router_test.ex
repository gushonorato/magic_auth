defmodule MagicAuth.RouterTest do
  use ExUnit.Case, async: true

  defmodule TestRouter do
    use MagicAuth.Router

    def scope(path, module, do: block), do: {path, module, block}
    def pipe_through(_), do: :ok
    def live(path, module, action), do: {path, module, action}
  end

  describe "magic_auth/2" do
    test "generates routes with default paths" do
      require TestRouter
      TestRouter.magic_auth()

      assert TestRouter.__magic_auth__(:scope) == "/sessions"
      assert TestRouter.__magic_auth__(:login) == "/sessions/login"
      assert TestRouter.__magic_auth__(:password) == "/sessions/password"
    end

    test "generates routes with custom scope" do
      require TestRouter
      TestRouter.magic_auth("/auth")

      assert TestRouter.__magic_auth__(:scope) == "/auth"
      assert TestRouter.__magic_auth__(:login) == "/auth/login"
      assert TestRouter.__magic_auth__(:password) == "/auth/password"
    end

    test "generates routes with custom paths" do
      require TestRouter
      TestRouter.magic_auth("/auth", login: "/entrar", password: "/senha")

      assert TestRouter.__magic_auth__(:scope) == "/auth"
      assert TestRouter.__magic_auth__(:login) == "/auth/entrar"
      assert TestRouter.__magic_auth__(:password) == "/auth/senha"
    end

    test "adds query parameters when provided" do
      require TestRouter
      TestRouter.magic_auth()

      query = %{redirect_to: "/dashboard"}
      assert TestRouter.__magic_auth__(:login, query) == "/sessions/login?redirect_to=/dashboard"
      assert TestRouter.__magic_auth__(:password, query) == "/sessions/password?redirect_to=/dashboard"
    end
  end
end
