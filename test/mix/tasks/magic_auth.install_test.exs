defmodule Mix.Tasks.MagicAuth.InstallTest do
  use ExUnit.Case, async: false

  import Mix.Tasks.MagicAuth.Install
  import ExUnit.CaptureIO

  def output_path, do: Application.fetch_env!(:magic_auth, :install_task_output_path)

  setup do
    Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
    Application.put_env(:lero_lero_app, :ecto_repos, [MagicAuth.TestRepo])

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
      Path.wildcard(Path.join(output_path(), "priv/test_repo/migrations/*_create_magic_auth_one_time_passwords.exs"))

    assert File.exists?(migration_file)

    content = File.read!(migration_file)
    assert content =~ "defmodule MagicAuth.TestRepo.Migrations.CreateMagicAuthOneTimePasswords"
    assert content =~ "create table(:magic_auth_one_time_passwords)"

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

    components_file = Path.join(output_path(), "lib/magic_auth_web/components/magic_auth.ex")

    assert File.exists?(components_file)

    content = File.read!(components_file)
    assert content =~ "defmodule MagicAuthWeb.MagicAuth"
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
