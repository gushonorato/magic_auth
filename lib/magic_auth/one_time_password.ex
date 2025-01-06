defmodule MagicAuth.OneTimePassword do
  use Ecto.Schema
  import Ecto.Changeset

  schema "magic_auth_one_time_passwords" do
    field :email, :string
    field :hashed_password, :string, redact: true

    timestamps(updated_at: false, type: :utc_datetime)
  end

  def email_pattern, do: ~r/^[^\s]+@[^\s]+\.[^\s]+$/

  def changeset(one_time_password, attrs) do
    one_time_password
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_format(:email, email_pattern())
  end

  def generate_code do
    MagicAuth.Config.one_time_password_length()
    |> :crypto.strong_rand_bytes()
    |> :binary.bin_to_list()
    |> Enum.map(&rem(&1, 10))
    |> Enum.join()
  end
end
