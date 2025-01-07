defmodule MagicAuth.SessionControllerTest do
  use MagicAuth.ConnCase, async: false

  alias MagicAuthTestWeb.Router

  @endpoint MagicAuthTestWeb.Endpoint

  setup do
    Application.put_env(:magic_auth, :otp_app, :magic_auth_test)
    Application.put_env(:magic_auth_test, :ecto_repos, [MagicAuthTest.Repo])
    Application.put_env(:magic_auth, :callbacks, MagicAuth.CallbacksMock)

    on_exit(fn ->
      Application.delete_env(:magic_auth, :otp_app)
      Application.delete_env(:magic_auth_test, :ecto_repos)
      Application.delete_env(:magic_auth, :callbacks)
    end)

    Mox.stub(MagicAuth.CallbacksMock, :one_time_password_requested, fn _code, _one_time_password -> :ok end)

    conn = build_conn() |> Plug.Test.init_test_session(%{})

    email = "usuario@exemplo.com.br"

    {:ok, conn: conn, email: email}
  end

  describe "verify/2" do
    test "redirects to login when email is invalid", %{conn: conn} do
      conn =
        get(conn, Router.__magic_auth__(:verify), %{
          "email" => "invalid_email",
          "code" => "123456"
        })

      assert redirected_to(conn) == Router.__magic_auth__(:log_in)
    end

    test "redirects to password page when code is invalid", %{conn: conn, email: email} do
      conn =
        get(conn, Router.__magic_auth__(:verify), %{
          "email" => email,
          # code too short
          "code" => "123"
        })

      assert redirected_to(conn) =~ Router.__magic_auth__(:password)
    end

    test "redirects with error when code is expired", %{conn: conn, email: email} do
      {:ok, {code, one_time_password}} = MagicAuth.create_one_time_password(%{"email" => email})

      one_time_password
      |> Ecto.Changeset.change(%{
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-11, :minute)
      })
      |> MagicAuth.Config.repo_module().update!()

      conn =
        get(conn, Router.__magic_auth__(:verify), %{
          "email" => email,
          "code" => code
        })

      assert redirected_to(conn) == Router.__magic_auth__(:password, %{email: email, error: :code_expired})
    end

    test "logs in when code is valid", %{conn: conn, email: email} do
      Mox.stub(MagicAuth.CallbacksMock, :log_in_requested, fn _email -> :allow end)
      {:ok, {code, _one_time_password}} = MagicAuth.create_one_time_password(%{"email" => email})

      conn =
        get(conn, Router.__magic_auth__(:verify), %{
          "email" => email,
          "code" => code
        })

      assert get_session(conn, :session_token) != nil
      assert redirected_to(conn) == "/"
    end
  end
end
