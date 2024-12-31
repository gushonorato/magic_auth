import Config

install_task_output_path = "test/mix/tasks/magic_auth_install_test_output_files"

if config_env() == :dev do
  config :mix_test_watch,
    exclude: [~r/#{install_task_output_path}/]
end

if config_env() == :test do
  config :magic_auth,
    install_task_output_path: install_task_output_path,
    repo: MagicAuth.TestRepo

  config :logger, level: :warning
end
