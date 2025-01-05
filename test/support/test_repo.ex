defmodule MagicAuth.TestRepo do
  use Ecto.Repo,
    otp_app: :magic_auth,
    adapter: Ecto.Adapters.Postgres
end
