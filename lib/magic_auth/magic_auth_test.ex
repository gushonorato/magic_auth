defmodule MagicAuth.TestHelpers do
  def log_in_session(conn, params) do
    session = MagicAuth.create_session!(params)
    MagicAuth.put_token_in_session(conn, session.token)
  end
end
