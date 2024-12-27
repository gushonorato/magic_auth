defmodule Mix.Tasks.MagicAuth.Install do
  use Mix.Task
  import Mix.Generator

  @shortdoc "Installs Magic Auth"

  @template_dir "priv/templates/magic_auth.install"

  def run(_args) do
    assigns = %{}
    install(assigns)
  end

  defp install(assigns) do
    install_magic_token_migration_file(assigns)

    Mix.shell().info("""
    Magic Auth installed successfully!

    Don't forget to run the migration:
        $ mix ecto.migrate
    """)
  end

  defp install_magic_token_migration_file(assigns) do
    timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.to_string() |> String.replace(["-", ":", " "], "")

    create_directory("priv/repo/migrations")

    copy_template(
      "#{@template_dir}/create_magic_auth_tokens.exs.eex",
      "priv/repo/migrations/#{timestamp}_create_magic_auth_tokens.exs",
      assigns
    )
  end
end
