defmodule MagicAuth.RouterTest do
  use ExUnit.Case, async: true

  alias MagicAuthTestWeb.Router

  defmodule CustomRouter do
    use Phoenix.Router, helpers: false
    use MagicAuth.Router

    import Plug.Conn
    import Phoenix.Controller
    import Phoenix.LiveView.Router

    pipeline :browser do
      plug :accepts, ["html"]
      plug :fetch_session
      plug :fetch_live_flash
      plug :protect_from_forgery
      plug :put_secure_browser_headers
    end

    magic_auth("/auth",
      log_in: "/entrar",
      password: "/senha",
      verify: "/verificar",
      log_out: "/sair",
      signed_in: "/seguro"
    )
  end

  describe "default routes" do
    test "generates routes with default paths" do
      routes = Router.__routes__()

      assert route_exists?(routes, "/sessions/log_in", nil)
      assert route_exists?(routes, "/sessions/password", nil)
      assert route_exists?(routes, "/sessions/verify", :verify)
      assert route_exists?(routes, "/sessions/log_out", :log_out)
    end

    test "generates introspection functions with default paths" do
      assert Router.__magic_auth__(:scope) == "/sessions"
      assert Router.__magic_auth__(:log_in, %{}) == "/sessions/log_in"
      assert Router.__magic_auth__(:password, %{}) == "/sessions/password"
      assert Router.__magic_auth__(:verify, %{}) == "/sessions/verify"
      assert Router.__magic_auth__(:log_out, %{}) == "/sessions/log_out"
      assert Router.__magic_auth__(:signed_in, %{}) == "/"
    end

    test "generates URLs with query parameters" do
      params = %{email: "test@example.com", foo: "bar"}

      assert Router.__magic_auth__(:log_in, params) |> URI.decode() ==
               "/sessions/log_in?foo=bar&email=test@example.com"

      assert Router.__magic_auth__(:password, params) |> URI.decode() ==
               "/sessions/password?foo=bar&email=test@example.com"

      assert Router.__magic_auth__(:verify, params) |> URI.decode() ==
               "/sessions/verify?foo=bar&email=test@example.com"

      assert Router.__magic_auth__(:signed_in, params) |> URI.decode() ==
               "/?foo=bar&email=test@example.com"

      assert Router.__magic_auth__(:log_out, params) |> URI.decode() ==
               "/sessions/log_out?foo=bar&email=test@example.com"
    end
  end

  describe "custom routes" do
    test "generates routes with custom paths" do
      routes = CustomRouter.__routes__()

      assert route_exists?(routes, "/auth/entrar", nil)
      assert route_exists?(routes, "/auth/senha", nil)
      assert route_exists?(routes, "/auth/verificar", :verify)
      assert route_exists?(routes, "/auth/sair", :log_out)
    end

    test "generates introspection functions with custom paths" do
      assert CustomRouter.__magic_auth__(:scope) == "/auth"
      assert CustomRouter.__magic_auth__(:log_in) == "/auth/entrar"
      assert CustomRouter.__magic_auth__(:password) == "/auth/senha"
      assert CustomRouter.__magic_auth__(:verify) == "/auth/verificar"
      assert CustomRouter.__magic_auth__(:log_out) == "/auth/sair"
      assert CustomRouter.__magic_auth__(:signed_in) == "/seguro"
    end

    test "generates custom URLs with query parameters" do
      params = %{email: "test@example.com", foo: "bar"}

      assert CustomRouter.__magic_auth__(:log_in, params) |> URI.decode() ==
               "/auth/entrar?foo=bar&email=test@example.com"

      assert CustomRouter.__magic_auth__(:password, params) |> URI.decode() ==
               "/auth/senha?foo=bar&email=test@example.com"

      assert CustomRouter.__magic_auth__(:verify, params) |> URI.decode() ==
               "/auth/verificar?foo=bar&email=test@example.com"

      assert CustomRouter.__magic_auth__(:signed_in, params) |> URI.decode() ==
               "/seguro?foo=bar&email=test@example.com"

      assert CustomRouter.__magic_auth__(:log_out, params) |> URI.decode() ==
               "/auth/sair?foo=bar&email=test@example.com"
    end
  end

  defp route_exists?(routes, path, action) do
    Enum.any?(routes, fn route ->
      route.path == path && route.plug_opts == action
    end)
  end
end
