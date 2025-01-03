defmodule MagicAuth do
  @moduledoc """
  Documentation for `MagicAuth`.
  """

  import Ecto.Query
  alias Ecto.Multi
  alias MagicAuth.OneTimePassword

  @doc """
  Generates a one-time password for a given email.

  The one-time password is stored in the database to allow users to log in from a device that
  doesn't have access to the email where the code was sent. For example, the user
  can receive the code on their phone and use it to log in on their computer.

  ## Parameters

    * `attrs` - A map containing `:email`

  ## Returns

    * `{:ok, one_time_password}` - Returns the created one-time password on success
    * `{:error, changeset}` - Returns the changeset with errors if validation fails
    * `{:error, failed_value}` - Returns the failed value if the transaction fails

  ## Examples

      iex> MagicAuth.generate_one_time_password(%{"email" => "user@example.com"})
      {:ok, %MagicAuth.OneTimePassword{}}

  The one time password length can be configured in config/config.exs:

      config :magic_auth,
        one_time_password_length: 6 # default value

  This function:
  1. Removes any existing one-time passwords for the provided email
  2. Generates a new random numeric password
  3. Encrypts the password using Bcrypt
  4. Stores the hash in the database
  """
  def generate_one_time_password(attrs) do
    changeset = MagicAuth.OneTimePassword.changeset(%MagicAuth.OneTimePassword{}, attrs)

    if changeset.valid? do
      code = OneTimePassword.generate_code()

      Multi.new()
      |> Multi.delete_all(
        :delete_one_time_passwords,
        from(t in MagicAuth.OneTimePassword, where: t.email == ^changeset.changes.email)
      )
      |> Multi.insert(:insert_one_time_password, fn _changes ->
        Ecto.Changeset.put_change(changeset, :hashed_password, Bcrypt.hash_pwd_salt(code))
      end)
      |> MagicAuth.Config.repo_module().transaction()
      |> case do
        {:ok, %{insert_one_time_password: one_time_password}} ->
          MagicAuth.Config.callback_module().on_one_time_password_generated(code, one_time_password)
          {:ok, one_time_password}

        {:error, _failed_operation, failed_value, _changes_so_far} ->
          {:error, failed_value}
      end
    else
      {:error, changeset}
    end
  end
end
