defmodule MagicAuth.SessionController do
  use Phoenix.Controller
  import Plug.Conn

  alias MagicAuth.OneTimePassword

  def verify(conn, %{"email" => email, "code" => code}) do
    cond do
      valid_email?(email) and valid_code?(code) ->
        process_verification(conn, email, code)

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

  defp process_verification(conn, email, code) do
    case MagicAuth.verify_password(email, code) do
      {:error, :invalid_code} ->
        redirect_to = MagicAuth.Config.router().__magic_auth__(:password, %{email: email, error: "invalid_code"})
        redirect(conn, to: redirect_to)

      {:error, :code_expired} ->
        redirect_to = MagicAuth.Config.router().__magic_auth__(:password, %{email: email, error: "code_expired"})
        redirect(conn, to: redirect_to)

      {:ok, _one_time_password} ->
        MagicAuth.log_in(conn, email)
    end
  end

  def log_out(conn, _params) do
    MagicAuth.log_out(conn)
  end
end
