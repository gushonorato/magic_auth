defmodule MagicAuth.TestHelpersTest do
  use MagicAuth.ConnCase, async: true
  alias MagicAuth.Session

  setup do
    conn = build_conn() |> Plug.Test.init_test_session(%{})
    %{conn: conn}
  end

  describe "log_in_session/2" do
    test "creates a session and puts token in session", %{conn: conn} do
      params = %{email: "test@example.com"}

      conn = MagicAuth.TestHelpers.log_in_session(conn, params)

      # Verify token is in session
      assert token = get_session(conn, :session_token)
      assert get_session(conn, :live_socket_id) == "magic_auth_sessions:#{Base.url_encode64(token)}"

      # Verify session was created
      assert %Session{email: "test@example.com"} = MagicAuth.get_session_by_token(token)
    end
  end
end
