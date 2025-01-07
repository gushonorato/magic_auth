defmodule MagicAuth do
  @moduledoc """
  Documentation for `MagicAuth`.
  """

  import Ecto.Query
  import Plug.Conn
  import Phoenix.Controller
  alias Ecto.Multi
  alias MagicAuth.{Session, OneTimePassword}

  @doc """
  Creates and sends a one-time password for a given email.

  The one-time password is stored in the database to allow users to log in from a device that
  doesn't have access to the email where the code was sent. For example, the user
  can receive the code on their phone and use it to log in on their computer.

  When called, this function creates a new one_time_password record and generates
  a one-time password that will be used to authenticate it. The password is then passed
  to the configured callback module `on_one_time_password_requested/2` which should handle
  sending it to the user via email.

  ## Parameters

    * `attrs` - A map containing `:email`

  ## Returns

    * `{:ok, one_time_password}` - Returns the created one_time_password on success
    * `{:error, changeset}` - Returns the changeset with errors if validation fails
    * `{:error, failed_value}` - Returns the failed value if the transaction fails

  ## Examples

      iex> MagicAuth.create_one_time_password(%{"email" => "user@example.com"})
      {:ok, {code, %MagicAuth.OneTimePassword{}}}

  The one time password length can be configured in config/config.exs:

  ```
  config :magic_auth,
    one_time_password_length: 6 # default value
  ```

  This function:
  1. Removes any existing one_time_passwords for the provided email
  2. Creates a new one_time_password
  3. Generates a new random numeric password
  4. Encrypts the password using Bcrypt
  5. Stores the hash in the database
  6. Calls the configured callback module's `on_one_time_password_requested/2` function
     which should handle sending the password to the user via email
  """
  def create_one_time_password(attrs) do
    changeset = MagicAuth.OneTimePassword.changeset(%MagicAuth.OneTimePassword{}, attrs)

    if changeset.valid? do
      code = OneTimePassword.generate_code()

      Multi.new()
      |> Multi.delete_all(
        :delete_one_time_passwords,
        from(s in MagicAuth.OneTimePassword, where: s.email == ^changeset.changes.email)
      )
      |> Multi.insert(:insert_one_time_passwords, fn _changes ->
        Ecto.Changeset.put_change(changeset, :hashed_password, Bcrypt.hash_pwd_salt(code))
      end)
      |> MagicAuth.Config.repo_module().transaction()
      |> case do
        {:ok, %{insert_one_time_passwords: one_time_password}} ->
          MagicAuth.Config.callback_module().on_one_time_password_requested(code, one_time_password)
          {:ok, {code, one_time_password}}

        {:error, _failed_operation, failed_value, _changes_so_far} ->
          {:error, failed_value}
      end
    else
      {:error, changeset}
    end
  end

  def verify_password(email, password) do
    one_time_password = MagicAuth.Config.repo_module().get_by(OneTimePassword, email: email)

    cond do
      is_nil(one_time_password) ->
        Bcrypt.no_user_verify()
        {:error, :invalid_code}

      DateTime.diff(DateTime.utc_now(), one_time_password.inserted_at, :minute) >
          MagicAuth.Config.one_time_password_expiration() ->
        {:error, :code_expired}

      Bcrypt.verify_pass(password, one_time_password.hashed_password) ->
        {:ok, one_time_password}

      true ->
        {:error, :invalid_code}
    end
  end

  @doc """
  Logs the session in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in(conn, email) do
    token = create_session(email)
    return_to = get_session(conn, :session_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token)
    |> redirect(to: return_to || MagicAuth.Config.router().__magic_auth__(:signed_in))
  end

  def create_session(email) do
    {token, session} = Session.build_session(email)
    MagicAuth.Config.repo_module().insert!(session)
    token
  end

  defp maybe_write_remember_me_cookie(conn, token) do
    if MagicAuth.Config.remember_me() do
      put_resp_cookie(conn, MagicAuth.Config.remember_me_cookie(), token, remember_me_options())
    else
      conn
    end
  end

  def remember_me_options() do
    [sign: true, max_age: MagicAuth.Config.session_validity_in_days() * 24 * 60 * 60, same_site: "Lax"]
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:session_token, token)
    |> put_session(:live_socket_id, "magic_auth_sessions:#{Base.url_encode64(token)}")
  end

  @doc """
  Gets the session with the given token.
  """
  def get_session_by_token(token) do
    {:ok, query} = Session.verify_session_token_query(token, MagicAuth.Config.session_validity_in_days())
    MagicAuth.Config.repo_module().one(query)
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out(conn) do
    session_token = get_session(conn, :session_token)
    session_token && delete_session_token(session_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      MagicAuth.Config.endpoint().broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(MagicAuth.Config.remember_me_cookie())
    |> redirect(to: "/")
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    MagicAuth.Config.repo_module().delete_all(from s in Session, where: s.token == ^token)
    :ok
  end
end
