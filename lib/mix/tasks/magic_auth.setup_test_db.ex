defmodule Mix.Tasks.MagicAuth.SetupTestDb do
  use Mix.Task

  def run(_args) do
    mix_env = Mix.env()

    Mix.env(:test)
    Mix.Task.run("loadconfig")
    Application.put_env(:magic_auth, :ecto_repos, [MagicAuthTest.Repo])
    Code.require_file("test/support/test_repo.ex")

    Mix.Tasks.Ecto.Drop.run(["--quiet"])

    output_migrations_path = Application.fetch_env!(:magic_auth, :install_task_output_path)

    File.rm_rf!(output_migrations_path)

    []
    |> Mix.Tasks.MagicAuth.Install.build_assigns()
    |> Mix.Tasks.MagicAuth.Install.install_magic_token_migration_file()

    Mix.Task.run("ecto.create", ["--quiet"])

    Mix.Task.run("ecto.migrate", [
      "--quiet",
      "--migrations-path",
      Path.join(["#{output_migrations_path}", "priv/test_repo/migrations"])
    ])

    File.rm_rf!(output_migrations_path)

    Mix.env(mix_env)
  end
end
