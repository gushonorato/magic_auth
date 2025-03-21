defmodule MagicAuth do
  @moduledoc """
  MagicAuth is an authentication library for Phoenix that provides effortless configuration and flexibility for your project.

  Key Features:

  - **Passwordless Authentication**: Secure login process through one-time passwords sent via email
  - **Enhanced Security**: Protect your application from brute force attacks with built-in rate limiting and account lockout mechanisms
  - **Customizable Interface**: Fully customizable UI components to match your design
  - **Effortless Configuration**: Quick and simple integration with your Phoenix project
  - **Schema Agnostic**: Implement authentication without requiring a user schema - ideal for everything from MVPs to complex applications

  To get started, see the installation documentation in `MagicAuth.MixProject`.
  """

  import Ecto.Query
  import Plug.Conn
  import Phoenix.Controller
  alias MagicAuth.TokenBuckets.LoginAttemptTokenBucket
  alias Ecto.Multi
  alias MagicAuth.{Session, OneTimePassword}
  alias MagicAuth.TokenBuckets.OneTimePasswordRequestTokenBucket

  @doc """
  Creates and sends a one-time password for a given email.

  The one-time password is stored in the database to allow users to log in from a device that
  doesn't have access to the email where the code was sent. For example, the user
  can receive the code on their phone and use it to log in on their computer.

  When called, this function creates a new one_time_password record and generates
  a one-time password that will be used to authenticate it. The password is then passed
  to the configured callback module `one_time_password_requested/1` which should handle
  sending it to the user via email.

  One-time password generation is rate limited using a token bucket system that allows a maximum of
  1 generation request per minute for each email address. This prevents abuse of the email delivery
  service.

  ## Parameters

    * `attrs` - A map containing `:email`

  ## Returns

    * `{:ok, code, one_time_password}` - Returns the created one_time_password on success
    * `{:error, changeset}` - Returns the changeset with errors if validation fails
    * `{:error, failed_value}` - Returns the failed value if the transaction fails
    * `{:error, :rate_limited, countdown}` - Returns the countdown if the rate limit is exceeded

  ## Examples

      iex> MagicAuth.create_one_time_password(%{"email" => "user@example.com"})
      {:ok, code, %MagicAuth.OneTimePassword{}}

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
  6. Calls the configured callback module's `one_time_password_requested/1` function
     which should handle sending the password to the user via email
  """
  def create_one_time_password(attrs) do
    changeset = MagicAuth.OneTimePassword.changeset(%MagicAuth.OneTimePassword{}, attrs)

    cond do
      changeset.valid? && MagicAuth.Config.rate_limit_enabled?() ->
        maybe_create_one_time_password(changeset)

      changeset.valid? && not MagicAuth.Config.rate_limit_enabled?() ->
        do_create_one_time_password(changeset)

      not changeset.valid? ->
        {:error, changeset}
    end
  end

  defp maybe_create_one_time_password(changeset) do
    case OneTimePasswordRequestTokenBucket.take(changeset.changes.email) do
      {:ok, _count} ->
        do_create_one_time_password(changeset)

      {:error, :rate_limited} ->
        {:error, :rate_limited, OneTimePasswordRequestTokenBucket.get_countdown()}
    end
  end

  defp do_create_one_time_password(changeset) do
    code = OneTimePassword.generate_code()

    Multi.new()
    |> Multi.delete_all(
      :delete_one_time_passwords,
      from(s in MagicAuth.OneTimePassword, where: s.email == ^changeset.changes.email)
    )
    |> Multi.insert(:insert_one_time_passwords, fn _changes ->
      Ecto.Changeset.put_change(changeset, :hashed_password, Bcrypt.hash_pwd_salt(code))
    end)
    |> MagicAuth.Repo.transaction()
    |> case do
      {:ok, %{insert_one_time_passwords: one_time_password}} ->
        MagicAuth.Config.callback_module().one_time_password_requested(%{code: code, email: one_time_password.email})
        {:ok, code, one_time_password}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
  end

  @doc """
  Verifies a one-time password for a given email.

  Takes an email and password as input and validates the one-time password.

  Returns:
  - `{:ok, one_time_password}` if the password is valid
  - `{:error, :invalid_code}` if the password is invalid or no password exists for email
  - `{:error, :code_expired}` if the password has expired

  The function:
  1. Looks up the one-time password record for the given email
  2. Returns error if no password exists (with timing attack protection)
  3. Checks if password has expired based on configured expiration time
  4. Verifies the provided password matches the stored hash
  """
  def verify_password(email, password) do
    one_time_password = MagicAuth.Repo.get_by(OneTimePassword, email: email)

    cond do
      is_nil(one_time_password) ->
        Bcrypt.no_user_verify()
        {:error, :invalid_code}

      DateTime.diff(DateTime.utc_now(), one_time_password.inserted_at, :minute) >
          MagicAuth.Config.one_time_password_expiration() ->
        {:error, :code_expired}

      Bcrypt.verify_pass(password, one_time_password.hashed_password) ->
        deleted_one_time_password = MagicAuth.Repo.delete!(one_time_password)
        {:ok, deleted_one_time_password}

      true ->
        {:error, :invalid_code}
    end
  end

  @doc """
  Logs the session in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks.

  Login attempts are rate limited using a token bucket that allows a maximum of
  10 attempts every 10 minutes per email address.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out.

  On login success:
    - Renews the session to prevent fixation attacks
    - Sets the token in session and cookie (if remember me is enabled)
    - Redirects to original page requested or to `/` (default route)

  On error:
    - If too many attempts: Redirects to `/sessions/log_in` with rate limit error message
    - If invalid code: Redirects to `/sessions/password`
    - If expired code: Redirects to `/sessions/password`
    - If access denied: Redirects to `/sessions/log_in` with access denied error message

  ## Denying access

  To deny access, implement the `log_in_requested/1` callback in your callback module
  returning `:deny`. For example:

  ```elixir
  def log_in_requested(email) do
    case Accounts.get_user_by_email(email) do
      %User{active: false} -> :deny  # Denies access for inactive users
      _ -> :allow
    end
  end
  ```
  For more information on denying access, see the comments for the `log_in_requested/1` function
  in the generated MagicAuth module in your application's codebase.

  ## Parameters
  - `conn`: The Plug.Conn connection
  - `email`: String containing the user's email address
  - `code`: String containing the one-time password code
  """
  def log_in(conn, email, code) do
    case LoginAttemptTokenBucket.take(email) do
      {:ok, _count} ->
        verify_password(conn, email, code)

      {:error, :rate_limited} ->
        error_message =
          MagicAuth.Config.callback_module().translate_error(:too_many_login_attempts,
            countdown: LoginAttemptTokenBucket.get_countdown()
          )

        conn
        |> put_flash(:error, error_message)
        |> redirect(to: MagicAuth.Config.router().__magic_auth__(:log_in))
    end
  end

  defp verify_password(conn, email, code) do
    case MagicAuth.verify_password(email, code) do
      {:error, :invalid_code} ->
        redirect_to = MagicAuth.Config.router().__magic_auth__(:password, %{email: email, error: "invalid_code"})
        redirect(conn, to: redirect_to)

      {:error, :code_expired} ->
        redirect_to = MagicAuth.Config.router().__magic_auth__(:password, %{email: email, error: "code_expired"})
        redirect(conn, to: redirect_to)

      {:ok, _one_time_password} ->
        perform_log_in(conn, email)
    end
  end

  defp perform_log_in(conn, email) do
    case MagicAuth.Config.callback_module().log_in_requested(%{email: email}) do
      :allow ->
        session = create_session!(%{email: email})
        setup_authenticated_session(conn, session)

      {:allow, user_id} ->
        session = create_session!(%{email: email, user_id: user_id})
        setup_authenticated_session(conn, session)

      :deny ->
        conn
        |> put_flash(:error, MagicAuth.Config.callback_module().translate_error(:access_denied, []))
        |> redirect(to: MagicAuth.Config.router().__magic_auth__(:log_in))
    end
  end

  @doc false
  def create_session!(attrs) do
    session = Session.build_session(attrs)
    MagicAuth.Repo.insert!(session)
  end

  defp setup_authenticated_session(conn, session) do
    return_to = get_session(conn, :session_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(session.token)
    |> maybe_write_remember_me_cookie(session.token)
    |> redirect(to: return_to || MagicAuth.Config.router().__magic_auth__(:signed_in))
  end

  defp maybe_write_remember_me_cookie(conn, token) do
    if MagicAuth.Config.remember_me() do
      put_resp_cookie(conn, MagicAuth.Config.remember_me_cookie(), token, remember_me_options())
    else
      conn
    end
  end

  @doc false
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
    MagicAuth.Repo.one(query)
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out(conn) do
    session_token = get_session(conn, :session_token)
    session_token && delete_all_sessions_by_token(session_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      MagicAuth.Config.endpoint().broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(MagicAuth.Config.remember_me_cookie())
    |> redirect(to: "/")
  end

  @doc """
  Deletes all sessions associated with a given token.
  """
  def delete_all_sessions_by_token(token) do
    MagicAuth.Repo.delete_all(from s in Session, where: s.token == ^token)
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
    MagicAuth.Repo.delete_all(from s in Session, where: s.email == ^email)
  end

  @doc """
  Authenticates the user session by looking into the session and remember me token.

  This function is designed to be used as a plug in your Phoenix router's pipeline.
  It fetches the user's session from either the session storage or the remember me cookie,
  and assigns the session and user (if available) to the connection.

  When a user is successfully authenticated:
  - `assigns[:current_session]` will contain the session data
  - `assigns[:current_user]` will contain the user data only if:
    1. A tuple `{:allow, user_id}` was returned from the `log_in_requested/1` callback during authentication
    2. The user can be retrieved using the configured `get_user` function. This function
       should be configured with `config :magic_auth, get_user: &MyApp.Accounts.get_user_by_id/1`. An error
       will be raised if the tuple is returned from the callback and the user schema is not configured.

  If the callback returned just `:allow` without a user_id, or if the user schema is not configured,
  `current_user` will be nil.

  ## Examples

      # In your router.ex
      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_live_flash
        plug :put_root_layout, {MyAppWeb.LayoutView, :root}
        plug :protect_from_forgery
        plug :put_secure_browser_headers
        plug :fetch_magic_auth_session
      end
  """
  def fetch_magic_auth_session(conn, _opts) do
    {session_token, conn} = ensure_user_session_token(conn)
    session = session_token && get_session_by_token(session_token)
    user = get_user_from_session(session)

    conn
    |> assign(:current_session, session)
    |> assign(:current_user, user)
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

  defp get_user_from_session(%Session{user_id: user_id}) when not is_nil(user_id) do
    MagicAuth.Repo.get_user(user_id)
  end

  defp get_user_from_session(_session), do: nil

  @doc """
  Plug function that verifies if the user is authenticated.

  If the user is not authenticated:
  - Stores the current URL in the session for later redirect
  - Redirects to the login page (defaults to: /session/log_in)
  - Shows unauthorized error message
  - Halts request processing

  If the user is authenticated:
  - Allows the request to continue normally with the session information
  - The current_session is available in conn.assigns[:current_session]

  ## Examples of usage

  In router.ex routes:
  ```elixir
  scope "/", MyAppWeb do
    pipe_through [:browser, :require_authenticated]

    get "/dashboard", DashboardController, :index
    live "/profile", ProfileLive
  end
  ```
  """
  def require_authenticated(conn, _opts) do
    if conn.assigns[:current_session] do
      conn
    else
      conn
      |> put_flash(:error, MagicAuth.Config.callback_module().translate_error(:unauthorized, []))
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
    if conn.assigns[:current_session] do
      conn
      |> redirect(to: MagicAuth.Config.router().__magic_auth__(:signed_in))
      |> halt()
    else
      conn
    end
  end

  @doc """
    Mount function for LiveViews that require authentication.

    This function:
    1. Mounts the user session on the socket
    2. Assigns the current user to the socket if a tuple `{:allow, user_id}` was returned from the
      `log_in_requested/1` callback during authentication
    3. Continues the mount flow if user is authenticated
    4. Halts and redirects to login page if user is not authenticated

  ## Examples of usage

  In LiveView modules:
  ```elixir
  defmodule MyAppWeb.DashboardLive do
    use MyAppWeb, :live_view

    on_mount {MagicAuth, :require_authenticated}

    def mount(_params, _session, socket) do
      {:ok, socket}
    end
  end
  ```

  In router.ex:
  ```elixir
  live_session :admin,
    on_mount: [{MagicAuth, :require_authenticated}] do
    live "/dashboard", DashboardLive
  end
  ```
  """
  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_magic_auth_session(socket, session)

    if socket.assigns.current_session do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, MagicAuth.Config.callback_module().translate_error(:unauthorized, []))
        |> Phoenix.LiveView.redirect(to: MagicAuth.Config.router().__magic_auth__(:log_in))

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_magic_auth_session(socket, session)

    if socket.assigns.current_session do
      {:halt, Phoenix.LiveView.redirect(socket, to: MagicAuth.Config.router().__magic_auth__(:signed_in))}
    else
      {:cont, socket}
    end
  end

  defp mount_magic_auth_session(socket, session) do
    socket =
      Phoenix.Component.assign_new(socket, :current_session, fn ->
        if session_token = session["session_token"] do
          get_session_by_token(session_token)
        end
      end)

    Phoenix.Component.assign_new(socket, :current_user, fn ->
      get_user_from_session(socket.assigns.current_session)
    end)
  end

  @doc """
  Returns a list of child processes that should be supervised.

  Includes token buckets needed for rate limiting:
  - OneTimePasswordRequestTokenBucket: Limits one-time password requests
  - LoginAttemptTokenBucket: Limits login attempts

  ## Example

  In your application.ex (this configuration is automatically added by the `mix magic_auth.install` task):
  ```elixir
  children = children ++ MagicAuth.children()
  ```
  """

  def children do
    [
      MagicAuth.TokenBuckets.OneTimePasswordRequestTokenBucket,
      MagicAuth.TokenBuckets.LoginAttemptTokenBucket
    ]
  end
end
