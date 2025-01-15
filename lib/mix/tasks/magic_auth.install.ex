defmodule Mix.Tasks.MagicAuth.Install do
  use Mix.Task
  import Mix.Generator
  import MagicAuth.Config
  @shortdoc "Installs Magic Auth"

  @template_dir "#{:code.priv_dir(:magic_auth)}/templates/magic_auth.install"

  def run(args) do
    args
    |> build_assigns()
    |> install()
  end

  def build_assigns(_args) do
    %{
      app_name: otp_app(),
      repo_module:
        repo_module()
        |> to_string()
        |> String.replace_prefix("Elixir.", ""),
      web_module:
        base()
        |> web_module()
        |> to_string()
        |> String.replace_prefix("Elixir.", ""),
      router_file_path: Path.join(["lib", "#{otp_app()}_web", "router.ex"])
    }
  end

  defp install(assigns) do
    install_magic_token_migration_file(assigns)
    install_magic_auth_callbacks(assigns)
    # inject_router(assigns)

    Mix.shell().info("""

    Magic Auth installed successfully!

    Don't forget to run the migration:
        $ mix ecto.migrate
    """)
  end

  def install_magic_token_migration_file(assigns) do
    copy_template(
      "#{@template_dir}/create_magic_auth_tables.exs.eex",
      migrations_path("#{generate_migration_timestamp()}_create_magic_auth_tables.exs"),
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
    copy_template(
      "#{@template_dir}/magic_auth.ex.eex",
      context_app() |> web_path("magic_auth.ex"),
      assigns
    )

    config_file = Path.join(["config/config.exs"])
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
