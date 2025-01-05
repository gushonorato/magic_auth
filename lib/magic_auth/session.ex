defmodule MagicAuth.Session do
  use Ecto.Schema

  schema "magic_auth_sessions" do
    field :email, :string
    field :token, :binary, redact: true

    timestamps(type: :utc_datetime)
  end

  def generate_token do
    :crypto.strong_rand_bytes(32)
  end
end
