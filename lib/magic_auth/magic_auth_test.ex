defmodule MagicAuth.TestHelpers do
  def log_in_session(conn, params) do
    session =
      conn
      |> MagicAuth.session_metadata()
      |> Map.merge(params)
      |> MagicAuth.create_session!()

    MagicAuth.put_token_in_session(conn, session.token)
  end
end
