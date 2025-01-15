defmodule Mix.Tasks.MagicAuth.InstallTest do
  use ExUnit.Case, async: false

  import Mix.Tasks.MagicAuth.Install
  import ExUnit.CaptureIO
  import MAgicAuthTest.MixHelpers

  setup do
    tmp = use_tmp_dir()

    Application.put_env(:magic_auth, :otp_app, :magic_auth_example)
    Application.put_env(:magic_auth_example, :ecto_repos, [MagicAuthTest.Repo])

    File.mkdir_p!("config")

    File.write!("config/config.exs", """
      import Config
    """)

    on_exit(fn ->
      teardown_tmp_dir(tmp)
    end)

    :ok
  end

  test "creates migration file successfully" do
      capture_io(fn ->
        run([])
      end)

    assert File.dir?(MagicAuth.Config.migrations_path())

    [migration_file] =
      [MagicAuth.Config.migrations_path(), "*_create_magic_auth_tables.exs"]
      |> Path.join()
      |> Path.wildcard()

    assert File.exists?(migration_file)

    content = File.read!(migration_file)
    assert content =~ "defmodule MagicAuthTest.Repo.Migrations.CreateMagicAuthOneTimePasswords"
    assert content =~ "create table(:magic_auth_one_time_passwords)"
  end

  test "creates magic auth callbacks file" do
    capture_io(fn ->
      run([])
    end)

    web_path = MagicAuth.Config.context_app() |> MagicAuth.Config.web_path()
    callbacks_file = "#{web_path}/magic_auth.ex"

    assert File.exists?(callbacks_file)

    content = File.read!(callbacks_file)
    assert content =~ "defmodule MagicAuthExampleWeb.MagicAuth"
    assert content =~ "use MagicAuthExampleWeb, :html"
    assert content =~ "def log_in_form(assigns) do"
    assert content =~ "def verify_form(assigns) do"
    assert content =~ "defp one_time_password_input(assigns) do"
    assert content =~ "def log_in_requested(_email), do: :allow"
    assert content =~ "def translate_error(:invalid_code, _opts), do: \"Invalid code\""
    assert content =~ "def translate_error(:code_expired, _opts), do: \"Code expired\""
    assert content =~ "def translate_error(:unauthorized, _opts), do: \"You need to log in to access this page.\""

    assert content =~
             "def translate_error(:access_denied, _opts), do: \"You don't have permission to access this page.\""

    assert content =~ "def translate_error(:too_many_one_time_password_requests, opts)"
  end

  test "injects configuration into config.exs" do
    capture_io(fn ->
      run([])
    end)

    config_content = File.read!("config/config.exs")

    assert config_content =~ "config :magic_auth, otp_app: :magic_auth_example"
  end

  test "doesn't duplicate configuration if already present" do
    File.rm("config/config.exs")

    File.write!("config/config.exs", """
    import Config
    config :magic_auth, otp_app: :magic_auth
    """)

    initial_content = File.read!("config/config.exs")

    capture_io(fn ->
      run([])
    end)

    final_content = File.read!("config/config.exs")

    assert initial_content == final_content
  end

  test "raises if config file is not found" do
    File.rm("config/config.exs")

    assert_raise File.Error, ~r/could not read file/, fn ->
      run([])
    end
  end
end
