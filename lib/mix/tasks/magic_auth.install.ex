defmodule Mix.Tasks.MagicAuth.Install do
  use Mix.Task
  import Mix.Generator

  @shortdoc "Installs Magic Auth"

  @template_dir "#{:code.priv_dir(:magic_auth)}/templates/magic_auth.install"

  def base_output_path do
    Application.get_env(:magic_auth, :install_task_output_path, "")
  end

  def repo_name do
    MagicAuth.Config.repo_module()
    |> Module.split()
    |> List.last()
  end

  def repo_path do
    repo_name() |> Macro.underscore()
  end

  def run(args) do
    Application.put_env(:magic_auth, :otp_app, Mix.Phoenix.otp_app())

    args
    |> build_assigns()
    |> install()
  end

  def build_assigns(_args) do
    %{
      app_name: Mix.Phoenix.otp_app(),
      base_module: Mix.Phoenix.base(),
      repo_module: repo_name(),
      web_module:
        Mix.Phoenix.base() |> Mix.Phoenix.web_module() |> Atom.to_string() |> String.replace_prefix("Elixir.", ""),
      migrations_path: Path.join(["priv", repo_path(), "migrations"])
    }
  end

  defp install(assigns) do
    install_magic_token_migration_file(assigns)
    install_magic_auth_callbacks(assigns)

    Mix.shell().info("""

    Magic Auth installed successfully!

    Don't forget to run the migration:
        $ mix ecto.migrate
    """)
  end

  def install_magic_token_migration_file(assigns) do
    copy_template(
      "#{@template_dir}/create_magic_auth_one_time_passwords.exs.eex",
      Path.join([
        base_output_path(),
        "priv",
        repo_path(),
        "migrations/#{generate_migration_timestamp()}_create_magic_auth_one_time_passwords.exs"
      ]),
      assigns
    )
  end

  defp generate_migration_timestamp do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
    |> String.replace(["-", ":", " "], "")
  end

  defp install_magic_auth_callbacks(assigns) do
    components_dir = Path.join([base_output_path(), "lib/#{assigns.app_name}_web/components"])

    copy_template(
      "#{@template_dir}/magic_auth.ex.eex",
      "#{components_dir}/magic_auth.ex",
      assigns
    )

    config_file = Path.join([base_output_path(), "config/config.exs"])
    Mix.shell().info(IO.ANSI.cyan() <> "* injecting " <> IO.ANSI.reset() <> "#{config_file}")

    config_content = File.read!(config_file)

    unless String.match?(config_content, ~r/config :magic_auth\b/) do
      File.write!(
        config_file,
        config_content <> "\n\nconfig :magic_auth, otp_app: :#{assigns.app_name}"
      )
    end
  end
end
