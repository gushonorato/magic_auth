import Config

install_task_output_path = "test/mix/tasks/magic_auth_install_test_output_files"

if config_env() == :dev do
  config :mix_test_watch,
    exclude: [~r/#{install_task_output_path}/]
end

if config_env() == :test do
  config :magic_auth,
    install_task_output_path: install_task_output_path

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
