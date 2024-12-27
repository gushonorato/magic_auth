defmodule Mix.Tasks.MagicAuth.Install do
  use Mix.Task
  import Mix.Generator

  @shortdoc "Installs Magic Auth"

  @template_dir "#{:code.priv_dir(:magic_auth)}/templates/magic_auth.install"

  def run(args) do
    args
    |> build_assigns()
    |> install()
  end

  defp build_assigns(_args) do
    %{
      app_name: Mix.Phoenix.otp_app(),
      base_module: Mix.Phoenix.base(),
      web_module:
        Mix.Phoenix.base() |> Mix.Phoenix.web_module() |> Atom.to_string() |> String.replace_prefix("Elixir.", "")
    }
  end

  defp install(assigns) do
    install_magic_token_migration_file(assigns)
    install_magic_auth_components(assigns)

    Mix.shell().info("""

    Magic Auth installed successfully!

    Don't forget to run the migration:
        $ mix ecto.migrate
    """)
  end

  defp install_magic_token_migration_file(assigns) do
    copy_template(
      "#{@template_dir}/create_magic_auth_tokens.exs.eex",
      "priv/repo/migrations/#{generate_migration_timestamp()}_create_magic_auth_tokens.exs",
      assigns
    )
  end

  defp generate_migration_timestamp do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
    |> String.replace(["-", ":", " "], "")
  end

  defp install_magic_auth_components(assigns) do
    components_dir = "lib/#{assigns.app_name}_web/components"

    copy_template(
      "#{@template_dir}/magic_auth_components.ex.eex",
      "#{components_dir}/magic_auth_components.ex",
      assigns
    )

    config_file = "config/config.exs"
    Mix.shell().info(IO.ANSI.cyan() <> "* injecting " <> IO.ANSI.reset() <> "#{config_file}")

    config_content = File.read!(config_file)

    unless String.match?(config_content, ~r/config :magic_auth\b/) do
      File.write!(
        config_file,
        config_content <> "\n\nconfig :magic_auth, ui_components: #{assigns.web_module}.MagicAuthComponents"
      )
    end
  end
end
