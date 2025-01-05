defmodule MagicAuth do
  @moduledoc """
  Documentation for `MagicAuth`.
  """

  import Ecto.Query
  alias Ecto.Multi
  alias MagicAuth.OneTimePassword

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
      {:ok, %MagicAuth.OneTimePassword{}}

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
          {:ok, one_time_password}

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
end
