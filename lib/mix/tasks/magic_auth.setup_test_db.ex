defmodule Mix.Tasks.MagicAuth.SetupTestDb do
  use Mix.Task

  def run(_args) do
    mix_env = Mix.env()

    try do
      Mix.env(:test)
      Mix.Task.run("loadconfig")
      Application.put_env(:magic_auth, :ecto_repos, [MagicAuthTest.Repo])
      Code.require_file("test/support/test_repo.ex")

      Mix.Tasks.Ecto.Drop.run(["--quiet"])

      []
      |> Mix.Tasks.MagicAuth.Install.build_assigns()
      |> Mix.Tasks.MagicAuth.Install.install_magic_token_migration_file()

      Mix.Task.run("ecto.create", ["--quiet"])

      Mix.Task.run("ecto.migrate", [
        "--quiet",
        "--migrations-path",
        "priv/test_repo/migrations"
      ])
    after
      File.rm_rf!("priv/test_repo/migrations")
      Mix.env(mix_env)
    end
  end
end
