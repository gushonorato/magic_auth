defmodule MagicAuth do
  @moduledoc """
  Documentation for `MagicAuth`.
  """

  import Ecto.Query
  alias Ecto.Multi
  alias MagicAuth.Session

  @doc """
  Creates an unauthenticated session and generates a one-time password for a given email.

  The one-time password is stored in the database to allow users to log in from a device that
  doesn't have access to the email where the code was sent. For example, the user
  can receive the code on their phone and use it to log in on their computer.

  When called, this function creates a new unauthenticated session record and generates
  a one-time password that will be used to authenticate it. The password is then passed
  to the configured callback module `on_one_time_password_requested/2` which should handle
  sending it to the user via email.

  ## Parameters

    * `attrs` - A map containing `:email`

  ## Returns

    * `{:ok, session}` - Returns the created unauthenticated session on success
    * `{:error, changeset}` - Returns the changeset with errors if validation fails
    * `{:error, failed_value}` - Returns the failed value if the transaction fails

  ## Examples

      iex> MagicAuth.create_unauthenticated_session(%{"email" => "user@example.com"})
      {:ok, %MagicAuth.Session{authenticated: false}}

  The one time password length can be configured in config/config.exs:

  ```
  config :magic_auth,
    one_time_password_length: 6 # default value
  ```

  This function:
  1. Removes any existing unauthenticated sessions for the provided email
  2. Creates a new unauthenticated session
  3. Generates a new random numeric password
  4. Encrypts the password using Bcrypt
  5. Stores the hash in the database
  6. Calls the configured callback module's `on_one_time_password_requested/2` function
     which should handle sending the password to the user via email
  """
  def create_unauthenticated_session(attrs) do
    changeset = MagicAuth.Session.changeset(%MagicAuth.Session{}, attrs)

    if changeset.valid? do
      code = Session.generate_code()

      Multi.new()
      |> Multi.delete_all(
        :delete_unauthenticated_sessions,
        from(s in MagicAuth.Session, where: s.email == ^changeset.changes.email and not s.authenticated?)
      )
      |> Multi.insert(:insert_unauthenticated_sessions, fn _changes ->
        Ecto.Changeset.put_change(changeset, :hashed_password, Bcrypt.hash_pwd_salt(code))
      end)
      |> MagicAuth.Config.repo_module().transaction()
      |> case do
        {:ok, %{insert_unauthenticated_sessions: session}} ->
          MagicAuth.Config.callback_module().on_one_time_password_requested(code, session)
          {:ok, session}

        {:error, _failed_operation, failed_value, _changes_so_far} ->
          {:error, failed_value}
      end
    else
      {:error, changeset}
    end
  end

  def verify_password(email, password) do
    session = MagicAuth.Config.repo_module().get_by(Session, email: email, authenticated?: false)

    cond do
      is_nil(session) ->
        Bcrypt.no_user_verify()
        {:error, :invalid_code}

      DateTime.diff(DateTime.utc_now(), session.inserted_at, :minute) > MagicAuth.Config.one_time_password_expiration() ->
        {:error, :code_expired}

      Bcrypt.verify_pass(password, session.hashed_password) ->
        {:ok, session}

      true ->
        {:error, :invalid_code}
    end
  end
end
