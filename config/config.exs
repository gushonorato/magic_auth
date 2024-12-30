import Config

if config_env() == :dev do
  config :mix_test_watch,
    exclude: [~r/test\/mix\/tasks\/magic_auth_install_test_output_files/]
end
