defmodule Mix.Tasks.MagicAuth.SetupTestDb do
  use Mix.Task

  def run(_args) do
    mix_env = Mix.env()

    try do
      Mix.env(:test)
      Mix.Task.run("loadconfig")
      Application.put_env(:magic_auth, :ecto_repos, [MagicAuthTest.Repo])
      Code.require_file("test/support/repo.ex")

      Mix.Tasks.Ecto.Drop.run(["--quiet"])

      Mix.Tasks.MagicAuth.Install.install_magic_token_migration_file()

      File.write!("priv/repo/migrations/20250321123456_create_users.exs", """
      defmodule MagicAuthTest.Repo.Migrations.CreateUsers do
        use Ecto.Migration

        def change do
          create table(:users) do
            add :email, :citext, null: false
          end
        end
      end
      """)

      Mix.Task.run("ecto.create", ["--quiet"])

      Mix.Task.run("ecto.migrate", [
        "--quiet",
        "--migrations-path",
        "priv/repo/migrations"
      ])
    after
      File.rm_rf!("priv/repo/migrations")
      Mix.env(mix_env)
    end
  end
end
