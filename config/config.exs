import Config

if config_env() == :dev do
  config :mix_test_watch,
    exclude: [~r/\/tmp/]
end

if config_env() == :test do
  config :magic_auth, MagicAuthTest.Repo,
    username: "postgres",
    password: "postgres",
    database: "magic_auth_test",
    hostname: "localhost",
    pool: Ecto.Adapters.SQL.Sandbox

  config :magic_auth, MagicAuthTestWeb.Endpoint,
    secret_key_base: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  config :logger, level: :warning
end
