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
    1..MagicAuth.Config.one_time_password_length()
    |> Enum.map(fn _ -> :crypto.strong_rand_bytes(1) |> :binary.decode_unsigned() |> rem(10) end)
    |> Enum.join("")
  end
end
