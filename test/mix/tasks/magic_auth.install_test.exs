defmodule Mix.Tasks.MagicAuth.InstallTest do
  use ExUnit.Case, async: false

  import Mix.Tasks.MagicAuth.Install
  import ExUnit.CaptureIO

  setup do
    on_exit(fn ->
      File.rm_rf!("priv/repo")
    end)

    :ok
  end

  test "creates migration file successfully" do
    # Capture console output during execution
    output =
      capture_io(fn ->
        run(%{})
      end)

    # Verify if migrations directory was created
    assert File.dir?("priv/repo/migrations")

    # Find the created migration file
    [migration_file] = Path.wildcard("priv/repo/migrations/*_create_magic_auth_tokens.exs")

    # Verify if file exists
    assert File.exists?(migration_file)

    # Verify if file content contains expected data
    content = File.read!(migration_file)
    assert content =~ "defmodule Repo.Migrations.CreateMagicAuthTokens"
    assert content =~ "create table(:magic_auth_tokens)"

    # Verify success message
    assert output =~ "Magic Auth installed successfully!"
  end

  test "run/1 executes installation" do
    output =
      capture_io(fn ->
        Mix.Tasks.MagicAuth.Install.run([])
      end)

    assert output =~ "Magic Auth installed successfully!"
  end
end
