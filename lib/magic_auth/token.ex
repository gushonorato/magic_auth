defmodule MagicAuth.Token do
  use Ecto.Schema
  import Ecto.Changeset

  schema "magic_auth_tokens" do
    field(:email, :string)
    field(:value, :string, redact: true)

    timestamps(updated_at: false)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:email, :value])
    |> validate_required([:email, :value])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
  end
end
