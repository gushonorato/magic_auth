defmodule MagicAuthTest do
  use MagicAuth.ConnCase, async: false

  import Mox
  import MagicAuthTest.Helpers

  require Phoenix.LiveView
  alias MagicAuth.{OneTimePassword, Session}

  setup :verify_on_exit!
  setup :preserve_app_env

  doctest MagicAuth, except: [create_one_time_password: 1]

  setup do
    Application.put_env(:magic_auth, :enable_rate_limit, false)

    Mox.stub(MagicAuthTestWeb.CallbacksMock, :one_time_password_requested, fn _params -> :ok end)
    Mox.stub(MagicAuthTestWeb.CallbacksMock, :log_in_requested, fn _params -> :allow end)

    conn =
      build_conn()
      |> Map.put(:secret_key_base, MagicAuthTestWeb.Endpoint.config(:secret_key_base))
      |> put_private(:phoenix_endpoint, MagicAuthTestWeb.Endpoint)
      |> Plug.Test.init_test_session(%{})

    email = "user@example.com"
    {:ok, code, one_time_password} = MagicAuth.create_one_time_password(%{"email" => email})

    %{conn: conn, email: email, code: code, one_time_password: one_time_password}
  end

  describe "create_one_time_password/1" do
    test "generates valid one-time password with valid email" do
      email = "user@example.com"
      {:ok, _code, token} = MagicAuth.create_one_time_password(%{"email" => email})

      assert token.email == email
      assert String.length(token.hashed_password) > 0
    end

    test "returns error with invalid email" do
      {:error, changeset} = MagicAuth.create_one_time_password(%{"email" => "invalid_email"})
      assert "has invalid format" in errors_on(changeset).email
    end

    test "removes existing tokens before creating a new one" do
      email = "user@example.com"
      {:ok, _code1, _token1} = MagicAuth.create_one_time_password(%{"email" => email})
      {:ok, _code2, token2} = MagicAuth.create_one_time_password(%{"email" => email})

      tokens = MagicAuthTest.Repo.all(OneTimePassword)
      assert length(tokens) == 1
      assert List.first(tokens).id == token2.id
    end

    test "does not remove one-time passwords from other emails", %{
      email: email,
      one_time_password: existing_one_time_password
    } do
      email2 = "user2@example.com"

      {:ok, _code2, one_time_password2} = MagicAuth.create_one_time_password(%{"email" => email2})
      {:ok, _code3, new_one_time_password1} = MagicAuth.create_one_time_password(%{"email" => email})

      one_time_passwords = MagicAuthTest.Repo.all(OneTimePassword)

      assert length(one_time_passwords) == 2
      refute Enum.any?(one_time_passwords, fn s -> s.id == existing_one_time_password.id end)
      assert Enum.any?(one_time_passwords, fn s -> s.id == one_time_password2.id end)
      assert Enum.any?(one_time_passwords, fn s -> s.id == new_one_time_password1.id end)
    end

    test "stores token value as bcrypt hash" do
      {:ok, _code, token} = MagicAuth.create_one_time_password(%{"email" => "user@example.com"})

      # Verify hashed_password starts with "$2b$" which is the bcrypt hash identifier
      assert String.starts_with?(token.hashed_password, "$2b$")
      # Verify hashed_password length is correct (60 characters)
      assert String.length(token.hashed_password) == 60
    end

    test "calls one_time_password_requested callback" do
      email = "user@example.com"

      expect(MagicAuthTestWeb.CallbacksMock, :one_time_password_requested, fn %{email: rec_email} ->
        assert rec_email == email
        :ok
      end)

      {:ok, _code, _token} = MagicAuth.create_one_time_password(%{"email" => email})
    end

    test "returns error when rate limit is reached" do
      config_sandbox(fn ->
        start_supervised!(MagicAuth.TokenBuckets.OneTimePasswordRequestTokenBucket)
        Application.put_env(:magic_auth, :enable_rate_limit, true)

        email = "user@example.com"

        assert {:ok, _code, _token} = MagicAuth.create_one_time_password(%{"email" => email})
        assert {:error, :rate_limited, _countdown} = MagicAuth.create_one_time_password(%{"email" => email})

        stop_supervised!(MagicAuth.TokenBuckets.OneTimePasswordRequestTokenBucket)
      end)
    end
  end

  describe "verify_password/2" do
    test "returns ok when password is correct and within expiration time" do
      email = "test@example.com"
      # assuming one_time_password_length is 6
      password = "123456"
      hashed_password = Bcrypt.hash_pwd_salt(password)

      # Create a valid one_time_password
      one_time_password =
        %OneTimePassword{
          email: email,
          hashed_password: hashed_password,
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
        |> MagicAuth.Config.repo_module().insert!()

      assert {:ok, returned_one_time_password} = MagicAuth.verify_password(email, password)
      assert returned_one_time_password.id == one_time_password.id
    end

    test "returns error when password is expired" do
      email = "test@example.com"
      password = "123456"
      hashed_password = Bcrypt.hash_pwd_salt(password)

      expiration = MagicAuth.Config.one_time_password_expiration() + 1

      # Create a one_time_password with old timestamp
      expired_time =
        DateTime.utc_now()
        |> DateTime.add(-expiration, :minute)
        |> DateTime.truncate(:second)

      %OneTimePassword{
        email: email,
        hashed_password: hashed_password,
        inserted_at: expired_time
      }
      |> MagicAuth.Config.repo_module().insert!()

      assert {:error, :code_expired} = MagicAuth.verify_password(email, password)
    end

    test "returns ok when password is within custom expiration time" do
      config_sandbox(fn ->
        email = "test@example.com"
        password = "123456"
        hashed_password = Bcrypt.hash_pwd_salt(password)

        # Configura tempo de expiração para 50 minutos
        Application.put_env(:magic_auth, :one_time_password_expiration, 50)

        # Cria uma sessão com timestamp de 45 minutos atrás
        past_time =
          DateTime.utc_now()
          |> DateTime.add(-45, :minute)
          |> DateTime.truncate(:second)

        one_time_password =
          %OneTimePassword{
            email: email,
            hashed_password: hashed_password,
            inserted_at: past_time
          }
          |> MagicAuth.Config.repo_module().insert!()

        assert {:ok, returned_one_time_password} = MagicAuth.verify_password(email, password)
        assert returned_one_time_password.id == one_time_password.id
      end)
    end

    test "returns error when password is incorrect" do
      email = "test@example.com"
      correct_password = "123456"
      wrong_password = "654321"
      hashed_password = Bcrypt.hash_pwd_salt(correct_password)

      # Create a valid one_time_password
      %OneTimePassword{
        email: email,
        hashed_password: hashed_password,
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
      |> MagicAuth.Config.repo_module().insert!()

      assert {:error, :invalid_code} = MagicAuth.verify_password(email, wrong_password)
    end

    test "returns error when email does not exist" do
      assert {:error, :invalid_code} = MagicAuth.verify_password("nonexistent@example.com", "123456")
    end
  end

  describe "one_time_password_length/0" do
    test "verifies default password length of 8 digits" do
      config_sandbox(fn ->
        # Configure password length to 8 digits
        Application.put_env(:magic_auth, :one_time_password_length, 8)

        email = "test@example.com"
        password = "12345678"
        hashed_password = Bcrypt.hash_pwd_salt(password)

        one_time_password =
          %OneTimePassword{
            email: email,
            hashed_password: hashed_password,
            inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
          }
          |> MagicAuth.Config.repo_module().insert!()

        assert {:ok, returned_one_time_password} = MagicAuth.verify_password(email, password)
        assert returned_one_time_password.id == one_time_password.id
      end)
    end
  end

  describe "log_in/3" do
    test "returns conn", %{conn: conn, code: code, email: email} do
      conn = MagicAuth.log_in(conn, email, code)
      assert %Plug.Conn{} = conn
    end

    test "stores user token in session", %{conn: conn, code: code, email: email} do
      conn = conn |> fetch_session() |> MagicAuth.log_in(email, code)

      assert token = get_session(conn, :session_token)
      assert get_session(conn, :live_socket_id) == "magic_auth_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == "/"
      assert %Session{} = MagicAuth.get_session_by_token(token)
    end

    test "clears everything previously stored in session", %{conn: conn, code: code, email: email} do
      conn = conn |> put_session(:to_be_removed, "value") |> MagicAuth.log_in(email, code)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to configured path", %{conn: conn, code: code, email: email} do
      conn = conn |> put_session(:session_return_to, "/hello") |> MagicAuth.log_in(email, code)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie when remember_me is configured", %{conn: conn, code: code, email: email} do
      conn = conn |> fetch_cookies() |> MagicAuth.log_in(email, code)
      assert get_session(conn, :session_token) == conn.cookies[MagicAuth.Config.remember_me_cookie()]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[MagicAuth.Config.remember_me_cookie()]
      assert signed_token != get_session(conn, :session_token)
      # 60 dias in seconds
      assert max_age == 5_184_000
    end

    test "does not write a cookie when remember_me is not configured", %{conn: conn, code: code, email: email} do
      config_sandbox(fn ->
        Application.put_env(:magic_auth, :remember_me, false)
        conn = conn |> fetch_cookies() |> MagicAuth.log_in(email, code)
        refute conn.resp_cookies[MagicAuth.Config.remember_me_cookie()]
      end)
    end

    test "changes session validity to 90 days", %{conn: conn, code: code, email: email} do
      config_sandbox(fn ->
        Application.put_env(:magic_auth, :session_validity_in_days, 90)
        conn = conn |> fetch_cookies() |> MagicAuth.log_in(email, code)

        assert %{max_age: max_age} = conn.resp_cookies[MagicAuth.Config.remember_me_cookie()]
        # 90 days in seconds
        assert max_age == 7_776_000
      end)
    end

    test "redirects to signed_in when log_in_requested returns :allow", %{conn: conn, code: code, email: email} do
      Mox.expect(MagicAuthTestWeb.CallbacksMock, :log_in_requested, fn %{email: ^email} -> :allow end)

      conn = MagicAuth.log_in(conn, email, code)

      assert redirected_to(conn) == "/"
      assert get_session(conn, :session_token)
    end

    test "redirects to signed_in when log_in_requested returns {:allow, user_id}", %{
      conn: conn,
      code: code,
      email: email
    } do
      user_id = 123
      Mox.expect(MagicAuthTestWeb.CallbacksMock, :log_in_requested, fn %{email: ^email} -> {:allow, user_id} end)

      conn = MagicAuth.log_in(conn, email, code)

      assert redirected_to(conn) == "/"
      assert get_session(conn, :session_token)

      # Verify the session was created with the user_id
      token = get_session(conn, :session_token)
      session = MagicAuth.get_session_by_token(token)
      assert session.user_id == user_id
    end

    test "redirects to log_in when log_in_requested returns :deny", %{conn: conn, code: code, email: email} do
      Mox.expect(MagicAuthTestWeb.CallbacksMock, :log_in_requested, fn %{email: ^email} -> :deny end)
      Mox.expect(MagicAuthTestWeb.CallbacksMock, :translate_error, fn :access_denied, _opts -> "Access denied" end)

      conn = conn |> fetch_flash() |> MagicAuth.log_in(email, code)

      assert redirected_to(conn) == MagicAuth.Config.router().__magic_auth__(:log_in)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Access denied"
      refute get_session(conn, :session_token)
    end
  end

  describe "get_session_by_token/1" do
    test "returns the session when token is valid", %{conn: conn, code: code, email: email} do
      conn = MagicAuth.log_in(conn, email, code)
      token = get_session(conn, :session_token)

      assert session = MagicAuth.get_session_by_token(token)
      assert session.email == email
    end

    test "returns nil when token is invalid" do
      assert MagicAuth.get_session_by_token("invalid_token") == nil
    end

    test "returns nil when token is expired", %{conn: conn, code: code, email: email} do
      conn = MagicAuth.log_in(conn, email, code)
      token = get_session(conn, :session_token)

      # Simulate a future date beyond validity period
      expired_days = -(MagicAuth.Config.session_validity_in_days() + 1)
      expired_date = DateTime.utc_now() |> DateTime.add(expired_days, :day) |> DateTime.truncate(:second)

      # Update session insertion date
      session = MagicAuth.get_session_by_token(token)

      Ecto.Changeset.change(session, inserted_at: expired_date)
      |> MagicAuth.Config.repo_module().update!()

      assert MagicAuth.get_session_by_token(token) == nil
    end
  end

  describe "log_out/1" do
    test "erases session and cookies", %{conn: conn, email: email} do
      session = MagicAuth.create_session!(%{email: email})
      session_token = session.token

      conn =
        conn
        |> put_session(:session_token, session_token)
        |> put_req_cookie(MagicAuth.Config.remember_me_cookie(), session_token)
        |> fetch_cookies()
        |> MagicAuth.log_out()

      refute get_session(conn, :session_token)
      refute conn.cookies[MagicAuth.Config.remember_me_cookie()]
      assert %{max_age: 0} = conn.resp_cookies[MagicAuth.Config.remember_me_cookie()]
      assert redirected_to(conn) == MagicAuth.Config.router().__magic_auth__(:log_in)
      refute MagicAuth.get_session_by_token(session_token)
    end

    test "works even if user is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> MagicAuth.log_out()
      refute get_session(conn, :session_token)
      assert %{max_age: 0} = conn.resp_cookies[MagicAuth.Config.remember_me_cookie()]
      assert redirected_to(conn) == MagicAuth.Config.router().__magic_auth__(:log_in)
    end
  end

  describe "session authentication" do
    test "fetch_magic_auth_session returns nil when there is no token", %{conn: conn} do
      conn = MagicAuth.fetch_magic_auth_session(conn, [])
      assert conn.assigns.current_session == nil
    end

    test "fetch_magic_auth_session loads session when token is valid", %{conn: conn} do
      email = "test@example.com"
      session = MagicAuth.create_session!(%{email: email})

      conn =
        conn
        |> put_session(:session_token, session.token)
        |> MagicAuth.fetch_magic_auth_session([])

      assert %Session{email: ^email} = conn.assigns.current_session
    end

    test "fetch_magic_auth_session loads user when token is valid", %{conn: conn} do
      config_sandbox(fn ->
        email = "test@example.com"
        user = MagicAuthTest.Repo.insert!(%MagicAuthTest.User{email: email})
        session = MagicAuth.create_session!(%{email: email, user_id: user.id})

        Application.put_env(:magic_auth, :get_user, fn _id -> user end)

        conn =
          conn
          |> put_session(:session_token, session.token)
          |> MagicAuth.fetch_magic_auth_session([])

        assert %Session{email: ^email} = conn.assigns.current_session
        assert conn.assigns.current_user == user
      end)
    end

    test "fetch_magic_auth_session does not load user when user_id of session is nil", %{conn: conn} do
      email = "test@example.com"
      session = MagicAuth.create_session!(%{email: email})

      conn =
        conn
        |> put_session(:session_token, session.token)
        |> MagicAuth.fetch_magic_auth_session([])

      assert conn.assigns.current_user == nil
    end

    test "fetch_magic_auth_session does not load user when token is invalid", %{conn: conn} do
      conn = MagicAuth.fetch_magic_auth_session(conn, [])
      assert conn.assigns.current_session == nil
    end
  end

  describe "require_authenticated/2" do
    test "redirects when not authenticated", %{conn: conn} do
      Mox.expect(MagicAuthTestWeb.CallbacksMock, :translate_error, fn :unauthorized, _opts ->
        "You must log in to access this page."
      end)

      conn = conn |> fetch_flash() |> MagicAuth.require_authenticated([])

      assert conn.halted
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You must log in to access this page."
      assert redirected_to(conn) == MagicAuth.Config.router().__magic_auth__(:log_in)
    end

    test "allows access when authenticated", %{conn: conn} do
      email = "test@example.com"
      session = MagicAuth.create_session!(%{email: email})

      conn =
        conn
        |> put_session(:session_token, session.token)
        |> assign(:current_session, %Session{email: email})
        |> MagicAuth.require_authenticated([])

      refute conn.halted
    end
  end

  describe "fetch_magic_auth_session/2" do
    test "loads session from session token when there is no remember_me cookie", %{conn: conn} do
      email = "test@example.com"
      session = MagicAuth.create_session!(%{email: email})

      conn =
        conn
        |> put_session(:session_token, session.token)
        |> MagicAuth.fetch_magic_auth_session([])

      assert %Session{email: ^email} = conn.assigns.current_session
    end

    test "loads session from remember_me cookie when there is no session token", %{conn: conn, email: email, code: code} do
      conn = MagicAuth.log_in(conn, email, code)
      conn = MagicAuth.fetch_magic_auth_session(conn, [])

      assert %Session{email: ^email} = conn.assigns.current_session
    end

    test "returns nil when there is no session token and no remember_me cookie", %{conn: conn} do
      conn = MagicAuth.fetch_magic_auth_session(conn, [])

      assert conn.assigns.current_session == nil
    end

    test "returns nil when remember_me cookie token is invalid", %{conn: conn} do
      conn =
        conn
        |> put_resp_cookie(MagicAuth.Config.remember_me_cookie(), "invalid_token", MagicAuth.remember_me_options())
        |> MagicAuth.fetch_magic_auth_session([])

      assert conn.assigns.current_session == nil
    end
  end

  describe "redirect_if_authenticated/2" do
    test "redirects when authenticated", %{conn: conn} do
      conn =
        conn
        |> assign(:current_session, %Session{email: "test@example.com"})
        |> MagicAuth.redirect_if_authenticated([])

      assert conn.halted
      assert redirected_to(conn) == MagicAuth.Config.router().__magic_auth__(:signed_in)
    end
  end

  describe "on_mount :require_authenticated" do
    test "redirects when not authenticated" do
      Mox.expect(MagicAuthTestWeb.CallbacksMock, :translate_error, fn :unauthorized, _opts ->
        "You must log in to access this page."
      end)

      socket = %Phoenix.LiveView.Socket{}
      socket = Map.put(socket, :assigns, Map.put(socket.assigns || %{}, :flash, %{}))
      session = %{}

      assert {:halt, socket} = MagicAuth.on_mount(:require_authenticated, %{}, session, socket)
      assert socket.assigns.current_session == nil
      assert socket.redirected == {:redirect, %{to: MagicAuth.Config.router().__magic_auth__(:log_in), status: 302}}
      assert Phoenix.Flash.get(socket.assigns.flash, :error) == "You must log in to access this page."
    end

    test "allows access when authenticated" do
      socket = %Phoenix.LiveView.Socket{}
      email = "test@example.com"
      session = MagicAuth.create_session!(%{email: email})
      session_data = %{"session_token" => session.token}

      assert {:cont, socket} = MagicAuth.on_mount(:require_authenticated, %{}, session_data, socket)
      assert %Session{email: ^email} = socket.assigns.current_session
    end

    test "loads user when session has user_id" do
      config_sandbox(fn ->
        user = MagicAuthTest.Repo.insert!(%MagicAuthTest.User{id: 1, email: "test@example.com"})

        Application.put_env(:magic_auth, :get_user, fn _id -> user end)

        socket = %Phoenix.LiveView.Socket{}
        session = MagicAuth.create_session!(%{email: "test@example.com", user_id: 1})
        session_data = %{"session_token" => session.token}

        assert {:cont, socket} = MagicAuth.on_mount(:require_authenticated, %{}, session_data, socket)
        assert %Session{email: "test@example.com", user_id: 1} = socket.assigns.current_session
        assert socket.assigns.current_user == user
      end)
    end

    test "current_user is nil when session has no user_id" do
      socket = %Phoenix.LiveView.Socket{}
      email = "test@example.com"
      session = MagicAuth.create_session!(%{email: email})
      session_data = %{"session_token" => session.token}

      assert {:cont, socket} = MagicAuth.on_mount(:require_authenticated, %{}, session_data, socket)
      assert %Session{email: ^email, user_id: nil} = socket.assigns.current_session
      assert socket.assigns.current_user == nil
    end
  end

  describe "on_mount :redirect_if_authenticated" do
    test "redirects when authenticated" do
      socket = %Phoenix.LiveView.Socket{}
      email = "test@example.com"
      session = MagicAuth.create_session!(%{email: email})
      session_data = %{"session_token" => session.token}

      assert {:halt, socket} = MagicAuth.on_mount(:redirect_if_authenticated, %{}, session_data, socket)
      assert socket.redirected == {:redirect, %{to: MagicAuth.Config.router().__magic_auth__(:signed_in), status: 302}}
    end

    test "allows access when not authenticated" do
      socket = %Phoenix.LiveView.Socket{}
      session = %{}

      assert {:cont, socket} = MagicAuth.on_mount(:redirect_if_authenticated, %{}, session, socket)
      assert socket.assigns.current_session == nil
    end
  end

  describe "log_out_all/1" do
    defmodule FakeLogoutEndpoint do
      def broadcast(socket_id, event, payload) do
        send(self(), {:broadcast, socket_id, event, payload})
        :ok
      end
    end

    test "deletes all sessions for a user", %{conn: conn} do
      config_sandbox(fn ->
        # Create multiple sessions for the same user
        user_id = 1
        session1 = MagicAuth.create_session!(%{email: "test1@example.com", user_id: user_id})
        session2 = MagicAuth.create_session!(%{email: "test2@example.com", user_id: user_id})

        # Create a session for a different user
        another_user_id = 2
        session3 = MagicAuth.create_session!(%{email: "test1@example.com", user_id: another_user_id})

        # Verify sessions exist
        assert MagicAuth.get_session_by_token(session1.token)
        assert MagicAuth.get_session_by_token(session2.token)

        Application.put_env(:magic_auth, :endpoint, MagicAuthTest.FakeLogoutEndpoint)

        conn = conn |> Plug.Conn.assign(:current_session, session1) |> Plug.Conn.assign(:current_user, %{id: user_id})

        # Call the function under test
        assert %Plug.Conn{} = MagicAuth.log_out_all(conn)

        # Verify sessions are deleted
        assert is_nil(MagicAuth.get_session_by_token(session1.token))
        assert is_nil(MagicAuth.get_session_by_token(session2.token))

        # Verify disconnect messages were broadcast
        socket_id1 = MagicAuth.live_socket_id(session1.token)
        socket_id2 = MagicAuth.live_socket_id(session2.token)
        assert_received {:broadcast, ^socket_id1, "disconnect", %{}}
        assert_received {:broadcast, ^socket_id2, "disconnect", %{}}

        # Verify disconnect messages were not broadcast for the different user
        socket_id3 = MagicAuth.live_socket_id(session3.token)
        refute_received {:broadcast, ^socket_id3, "disconnect", %{}}
      end)
    end

    test "does not disconnect current session when disconnect_self is false", %{conn: conn} do
      config_sandbox(fn ->
        # Create multiple sessions for the same user
        user_id = 1
        session1 = MagicAuth.create_session!(%{email: "test1@example.com", user_id: user_id})
        session2 = MagicAuth.create_session!(%{email: "test2@example.com", user_id: user_id})

        Application.put_env(:magic_auth, :endpoint, MagicAuthTest.FakeLogoutEndpoint)

        # Setup conn with current user and current session
        conn =
          conn
          |> Plug.Conn.assign(:current_user, %{id: user_id})
          |> Plug.Conn.assign(:current_session, session1)

        # Call the function under test with disconnect_self: false
        MagicAuth.log_out_all(conn, disconnect_self: false)

        # Verify sessions are deleted
        assert is_nil(MagicAuth.get_session_by_token(session1.token))
        assert is_nil(MagicAuth.get_session_by_token(session2.token))

        # Verify disconnect message was not sent for current session
        socket_id1 = MagicAuth.live_socket_id(session1.token)
        refute_received {:broadcast, ^socket_id1, "disconnect", %{}}

        # Verify disconnect message was sent for other session
        socket_id2 = MagicAuth.live_socket_id(session2.token)
        assert_received {:broadcast, ^socket_id2, "disconnect", %{}}
      end)
    end
  end
end
