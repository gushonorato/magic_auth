Application.put_env(:magic_auth, MagicAuth.TestRepo,
  username: "postgres",
  password: "postgres",
  database: "magic_auth_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
)

Application.put_env(:magic_auth, :ecto_repos, [MagicAuth.TestRepo])
Application.put_env(:magic_auth, :repo, MagicAuth.TestRepo)

defmodule MagicAuth.TestRepo do
  use Ecto.Repo,
    otp_app: :magic_auth,
    adapter: Ecto.Adapters.Postgres
end
