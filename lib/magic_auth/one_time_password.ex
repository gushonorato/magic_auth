defmodule MagicAuth.OneTimePassword do
  use Ecto.Schema
  import Ecto.Changeset

  schema "magic_auth_one_time_passwords" do
    field(:email, :string)
    field(:hashed_password, :string, redact: true)

    timestamps(updated_at: false)
  end

  def changeset(one_time_password, attrs) do
    one_time_password
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
  end

  def generate_code do
    1..MagicAuth.Config.one_time_password_length()
    |> Enum.map_join(fn _ -> Enum.random(0..9) end)
  end
end
