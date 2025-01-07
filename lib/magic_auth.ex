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
  to the configured callback module `one_time_password_requested/2` which should handle
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
  6. Calls the configured callback module's `one_time_password_requested/2` function
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
          MagicAuth.Config.callback_module().one_time_password_requested(code, one_time_password)
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
    session = create_session!(email)
    return_to = get_session(conn, :session_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(session.token)
    |> maybe_write_remember_me_cookie(session.token)
    |> redirect(to: return_to || MagicAuth.Config.router().__magic_auth__(:signed_in))
  end

  def create_session!(email) do
    session = Session.build_session(email)
    MagicAuth.Config.repo_module().insert!(session)
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
    session_token && delete_sessions_by_token(session_token)

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
  def delete_sessions_by_token(token) do
    MagicAuth.Config.repo_module().delete_all(from s in Session, where: s.token == ^token)
    :ok
  end

  @doc """
  Deletes all sessions associated with a given email.

  This function should be called when a user is deleted or has their email changed,
  to ensure that all their active sessions are terminated.

  ## Parameters

    * `email` - The email of the user whose sessions should be deleted

  ## Examples

      iex> MagicAuth.delete_all_sessions_by_email("user@example.com")
      {0, nil} # where n is the number of deleted sessions
  """
  def delete_all_sessions_by_email(email) do
    MagicAuth.Config.repo_module().delete_all(from s in Session, where: s.email == ^email)
  end

  @doc """
  Authenticates the user session by looking into the session
  and remember me token.
  """
  def fetch_current_user_session(conn, _opts) do
    {session_token, conn} = ensure_user_session_token(conn)
    session = session_token && get_session_by_token(session_token)
    assign(conn, :current_user_session, session)
  end

  defp ensure_user_session_token(conn) do
    if token = get_session(conn, :session_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [MagicAuth.Config.remember_me_cookie()])

      if token = conn.cookies[MagicAuth.Config.remember_me_cookie()] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Used for routes that require the authenticated sessions.
  """
  def require_authenticated(conn, _opts) do
    if conn.assigns[:current_user_session] do
      conn
    else
      conn
      |> put_flash(:error, MagicAuth.Config.callback_module().translate_error(:unauthorized))
      |> maybe_store_return_to()
      |> redirect(to: MagicAuth.Config.router().__magic_auth__(:log_in))
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :session_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_authenticated(conn, _opts) do
    if conn.assigns[:current_user_session] do
      conn
      |> redirect(to: MagicAuth.Config.router().__magic_auth__(:signed_in))
      |> halt()
    else
      conn
    end
  end

  def on_mount(:mount_current_user_session, _params, session, socket) do
    {:cont, mount_current_user_session(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_user_session(socket, session)

    if socket.assigns.current_user_session do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, MagicAuth.Config.callback_module().translate_error(:unauthorized))
        |> Phoenix.LiveView.redirect(to: MagicAuth.Config.router().__magic_auth__(:log_in))

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_user_session(socket, session)

    if socket.assigns.current_user_session do
      {:halt, Phoenix.LiveView.redirect(socket, to: MagicAuth.Config.router().__magic_auth__(:signed_in))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user_session(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user_session, fn ->
      if session_token = session["session_token"] do
        get_session_by_token(session_token)
      end
    end)
  end
end
