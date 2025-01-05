defmodule MagicAuth.VerifyController do
  use Phoenix.Controller
  import Plug.Conn

  alias MagicAuth.Session

  def verify(conn, %{"email" => email, "code" => code}) do
    cond do
      valid_email?(email) and valid_code?(code) ->
        process_verification(conn, email, code)

      valid_email?(email) and not valid_code?(code) ->
        redirect_to = MagicAuth.Config.router().__magic_auth__(:password, %{email: email})
        redirect(conn, to: redirect_to)

      not valid_email?(email) ->
        redirect_to = MagicAuth.Config.router().__magic_auth__(:login)
        redirect(conn, to: redirect_to)
    end
  end

  defp valid_email?(email), do: String.match?(email, Session.email_pattern())
  defp valid_code?(code), do: String.length(code) == MagicAuth.Config.one_time_password_length()

  defp process_verification(conn, email, code) do
    case MagicAuth.verify_password(email, code) do
      {:error, :invalid_code} ->
        redirect_to = MagicAuth.Config.router().__magic_auth__(:password, %{email: email, error: "invalid_code"})
        redirect(conn, to: redirect_to)

      {:error, :code_expired} ->
        redirect_to = MagicAuth.Config.router().__magic_auth__(:password, %{email: email, error: "code_expired"})
        redirect(conn, to: redirect_to)

      {:ok, _session} ->
        redirect_to = get_session(conn, :redirect_to) || "/"
        redirect(conn, to: redirect_to)
    end
  end
end
