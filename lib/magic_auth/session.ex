defmodule MagicAuth.Session do
  use Ecto.Schema
  import Ecto.Changeset

  schema "magic_auth_sessions" do
    field :email, :string
    field :hashed_password, :string, redact: true
    field :authenticated?, :boolean, default: false, source: :authenticated

    timestamps(updated_at: false, type: :utc_datetime)
  end

  def email_pattern, do: ~r/^[^\s]+@[^\s]+\.[^\s]+$/

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_format(:email, email_pattern())
  end

  def generate_code do
    1..MagicAuth.Config.one_time_password_length()
    |> Enum.map_join(fn _ -> Enum.random(0..9) end)
  end
end
