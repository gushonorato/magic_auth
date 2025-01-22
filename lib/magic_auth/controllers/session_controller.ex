defmodule MagicAuth.SessionController do
  @moduledoc false

  use Phoenix.Controller
  import Plug.Conn

  alias MagicAuth.OneTimePassword

  def verify(conn, %{"email" => email, "code" => code}) do
    cond do
      valid_email?(email) and valid_code?(code) ->
        MagicAuth.log_in(conn, email, code)

      valid_email?(email) and not valid_code?(code) ->
        redirect_to = MagicAuth.Config.router().__magic_auth__(:password, %{email: email})
        redirect(conn, to: redirect_to)

      not valid_email?(email) ->
        redirect_to = MagicAuth.Config.router().__magic_auth__(:log_in)
        redirect(conn, to: redirect_to)
    end
  end

  defp valid_email?(email), do: String.match?(email, OneTimePassword.email_pattern())
  defp valid_code?(code), do: String.length(code) == MagicAuth.Config.one_time_password_length()

  def log_out(conn, _params) do
    MagicAuth.log_out(conn)
  end
end
