defmodule Mix.Tasks.MagicAuth.InstallTest do
  use ExUnit.Case, async: false

  import Mix.Tasks.MagicAuth.Install
  import ExUnit.CaptureIO

  def output_path, do: "test/mix/tasks/magic_auth_install_test_output_files"

  setup do
    File.mkdir_p!(Path.join(output_path(), "config"))
    File.mkdir_p!(Path.join(output_path(), "config"))

    File.write!(Path.join(output_path(), "config/config.exs"), """
    use Mix.Config
    """)

    on_exit(fn ->
      File.rm_rf!(output_path())
    end)

    :ok
  end

  test "creates migration file successfully" do
    output =
      capture_io(fn ->
        run(%{})
      end)

    assert File.dir?(Path.join(output_path(), "priv/test_repo/migrations"))

    [migration_file] =
      Path.wildcard(Path.join(output_path(), "priv/test_repo/migrations/*_create_magic_auth_tokens.exs"))

    assert File.exists?(migration_file)

    content = File.read!(migration_file)
    assert content =~ "defmodule Repo.Migrations.CreateMagicAuthTokens"
    assert content =~ "create table(:magic_auth_tokens)"

    assert output =~ "Magic Auth installed successfully!"
  end

  test "run/1 executes installation" do
    output =
      capture_io(fn ->
        Mix.Tasks.MagicAuth.Install.run([])
      end)

    assert output =~ "Magic Auth installed successfully!"
  end

  test "creates magic auth components file" do
    capture_io(fn ->
      run([])
    end)

    components_file = Path.join(output_path(), "lib/magic_auth_web/components/magic_auth_components.ex")

    assert File.exists?(components_file)

    content = File.read!(components_file)
    assert content =~ "defmodule MagicAuthWeb.MagicAuthComponents"
    assert content =~ "use MagicAuthWeb, :html"
    assert content =~ "def login_form(assigns) do"
    assert content =~ "def one_time_password_form(assigns) do"
    assert content =~ "defp one_time_password_input(assigns) do"
  end

  test "injects configuration into config.exs" do
    capture_io(fn ->
      run([])
    end)

    config_content = File.read!(Path.join(output_path(), "config/config.exs"))

    assert config_content =~ "config :magic_auth, ui_components: MagicAuthWeb.MagicAuthComponents"
  end

  test "doesn't duplicate configuration if already present" do
    File.rm(Path.join(output_path(), "config/config.exs"))

    File.write!(Path.join(output_path(), "config/config.exs"), """
    use Mix.Config
    config :magic_auth, ui_components: MagicAuthWeb.MagicAuthComponents
    """)

    initial_content = File.read!(Path.join(output_path(), "config/config.exs"))

    capture_io(fn ->
      run([])
    end)

    final_content = File.read!(Path.join(output_path(), "config/config.exs"))

    assert initial_content == final_content
  end

  test "raises if config file is not found" do
    File.rm(Path.join(output_path(), "config/config.exs"))

    assert_raise File.Error, ~r/could not read file/, fn ->
      run([])
    end
  end
end
