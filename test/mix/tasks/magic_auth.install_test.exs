defmodule Mix.Tasks.MagicAuth.InstallTest do
  use ExUnit.Case, async: false

  import Mix.Tasks.MagicAuth.Install
  import ExUnit.CaptureIO

  def output_path, do: Application.fetch_env!(:magic_auth, :install_task_output_path)

  setup do
    Application.put_env(:magic_auth, :ecto_repos, [MagicAuthTest.Repo])

    File.mkdir_p!(Path.join(output_path(), "config"))
    File.mkdir_p!(Path.join(output_path(), "config"))

    File.write!(Path.join(output_path(), "config/config.exs"), """
    use Mix.Config
    """)

    on_exit(fn ->
      File.rm_rf!(output_path())
      Application.delete_env(:magic_auth, :ecto_repos)
    end)

    :ok
  end

  test "creates migration file successfully" do
    output =
      capture_io(fn ->
        run(%{})
      end)

    assert File.dir?(Path.join(output_path(), "priv/repo/migrations"))

    [migration_file] =
      Path.wildcard(Path.join(output_path(), "priv/repo/migrations/*_create_magic_auth_tables.exs"))

    assert File.exists?(migration_file)

    content = File.read!(migration_file)
    assert content =~ "defmodule MagicAuthTest.Repo.Migrations.CreateMagicAuthOneTimePasswords"
    assert content =~ "create table(:magic_auth_one_time_passwords)"

    assert output =~ "Magic Auth installed successfully!"
  end

  test "run/1 executes installation" do
    output =
      capture_io(fn ->
        run([])
      end)

    assert output =~ "Magic Auth installed successfully!"
  end

  test "creates magic auth callbacks file" do
    capture_io(fn ->
      run([])
    end)

    components_file = Path.join(output_path(), "lib/magic_auth_web/magic_auth.ex")

    assert File.exists?(components_file)

    content = File.read!(components_file)
    assert content =~ "defmodule MagicAuthWeb.MagicAuth"
    assert content =~ "use MagicAuthWeb, :html"
    assert content =~ "def log_in_form(assigns) do"
    assert content =~ "def verify_form(assigns) do"
    assert content =~ "defp one_time_password_input(assigns) do"
    assert content =~ "def translate_error(:invalid_code), do: \"Invalid code\""
    assert content =~ "def translate_error(:code_expired), do: \"Code expired\""
    assert content =~ "def translate_error(:unauthorized), do: \"You need to log in to access this page.\""
    assert content =~ "def translate_error(:access_denied), do: \"You don't have permission to access this page.\""
  end

  test "injects configuration into config.exs" do
    capture_io(fn ->
      run([])
    end)

    config_content = File.read!(Path.join(output_path(), "config/config.exs"))

    assert config_content =~ "config :magic_auth, otp_app: :magic_auth"
  end

  test "doesn't duplicate configuration if already present" do
    File.rm(Path.join(output_path(), "config/config.exs"))

    File.write!(Path.join(output_path(), "config/config.exs"), """
    use Mix.Config
    config :magic_auth, otp_app: :magic_auth
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
