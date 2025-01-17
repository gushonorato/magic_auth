defmodule Mix.Tasks.MagicAuth.InstallTest do
  use ExUnit.Case, async: false

  import Mix.Tasks.MagicAuth.Install
  import ExUnit.CaptureIO
  import MagicAuthTest.Helpers

  setup do
    preserve_app_env()
  end

  setup do
    tmp = use_tmp_dir()

    Application.put_env(:magic_auth, :ecto_repos, [MagicAuthTest.Repo])

    File.mkdir_p!("config")

    File.write!("config/config.exs", """
      import Config
    """)

    web_path = Mix.Phoenix.web_path(Mix.Phoenix.context_app())
    File.mkdir_p!(web_path)

    router_file_path = Path.join(web_path, "router.ex")

    File.write!(router_file_path, """
      defmodule MagicAuthtWeb.Router do
        use MagicAuthWeb, :router

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_live_flash
          plug :put_root_layout, html: {MagicAuthTestWeb.Layouts, :root}
          plug :protect_from_forgery
          plug :put_secure_browser_headers
        end
      end
    """)

    File.mkdir_p!(Mix.Phoenix.context_app() |> Mix.Phoenix.context_lib_path(""))
    application_file_path = Mix.Phoenix.context_app() |> Mix.Phoenix.context_lib_path("application.ex")

    File.write!(application_file_path, """
    defmodule MagicAuthTest.Application do
      def start(_type, _args) do
        children = [
          MagicAuthTest.Repo,
          MagicAuthTestWeb.Endpoint
        ]

        opts = [strategy: :one_for_one, name: MagicAuthTest.Supervisor]
        Supervisor.start_link(children, opts)
      end
    end
    """)

    on_exit(fn ->
      teardown_tmp_dir(tmp)
    end)

    %{web_path: web_path, router_file_path: router_file_path, application_file_path: application_file_path, tmp: tmp}
  end

  test "displays success message" do
    Mix.shell(Mix.Shell.IO)

    output =
      capture_io(fn ->
        run([])
      end)

    assert output =~ "Magic Auth installed successfully!"
  after
    Mix.shell(Mix.Shell.Process)
  end

  test "creates migration file successfully" do
    capture_io(fn ->
      run([])
    end)

    migrations_path = "priv/repo/migrations"

    assert File.dir?(migrations_path)

    migrations =
      [migrations_path, "*_create_magic_auth_tables.exs"]
      |> Path.join()
      |> Path.wildcard()

    assert Enum.count(migrations) == 1

    [migration_file] = migrations
    content = File.read!(migration_file)
    assert content =~ "defmodule MagicAuthTest.Repo.Migrations.CreateMagicAuthOneTimePasswords"
    assert content =~ "create table(:magic_auth_one_time_passwords)"
  end

  test "creates magic auth callbacks file" do
    capture_io(fn ->
      run([])
    end)

    web_path = Mix.Phoenix.context_app() |> Mix.Phoenix.web_path()
    callbacks_file = "#{web_path}/magic_auth.ex"

    assert File.exists?(callbacks_file)

    content = File.read!(callbacks_file)
    assert content =~ "defmodule MagicAuthWeb.MagicAuth"
    assert content =~ "MagicAuth.Mailer"
    assert content =~ "use MagicAuthWeb, :html"
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
    Application.put_env(:magic_auth, :context_app, :magic_auth_test)

    capture_io(fn ->
      run([])
    end)

    config_content = File.read!("config/config.exs")

    assert config_content =~ """
           config :magic_auth,
             callbacks: MagicAuthWeb.MagicAuth,
             repo: MagicAuthTest.Repo,
             router: MagicAuthWeb.Router,
             endpoint: MagicAuthWeb.Endpoint,
             remember_me_cookie: "_magic_auth_remember_me"
           """
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
      capture_io(fn ->
        run([])
      end)
    end
  end

  test "injects router configuration", %{router_file_path: router_file_path} do
    capture_io(fn ->
      run([])
    end)

    router_content = File.read!(router_file_path)

    assert router_content =~ "use MagicAuth.Router"
    assert router_content =~ "magic_auth()"
    assert router_content =~ "plug :fetch_current_user_session"
  end

  test "does not duplicate router configuration if already present", %{router_file_path: router_file_path} do
    File.write!(router_file_path, """
    defmodule MagicAuthTestWeb.Router do
      use MagicAuthTestWeb, :router
      use MagicAuth.Router

      magic_auth()

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_live_flash
        plug :protect_from_forgery
        plug :put_secure_browser_headers
        plug :fetch_current_user_session
      end
    end
    """)

    initial_content = File.read!(router_file_path)

    capture_io(fn ->
      run([])
    end)

    final_content = File.read!(router_file_path)
    assert initial_content == final_content
  end

  test "displays error message when unable to inject router configuration", %{router_file_path: router_file_path} do
    Mix.shell(Mix.Shell.IO)
    File.rm_rf!(router_file_path)

    File.write!(router_file_path, """
    defmodule MagicAuthTestWeb.Router do
      # Different format than expected
    end
    """)

    output =
      capture_io(fn ->
        run([])
      end)

    assert output =~ "The task was unable to add some configuration to your router.ex"
    assert output =~ "You should manually add the following code to your router.ex"
  after
    Mix.shell(Mix.Shell.Process)
  end

  test "installs token buckets configuration", %{application_file_path: application_file_path} do
    Mix.shell(Mix.Shell.IO)

    capture_io(fn ->
      run([])
    end)

    content = File.read!(application_file_path)

    assert content == """
           defmodule MagicAuthTest.Application do
             def start(_type, _args) do
               children = [
                 MagicAuthTest.Repo,
                 MagicAuthTestWeb.Endpoint
               ]
               children = children ++ MagicAuth.supervised_children()

               opts = [strategy: :one_for_one, name: MagicAuthTest.Supervisor]
               Supervisor.start_link(children, opts)
             end
           end
           """
  after
    Mix.shell(Mix.Shell.Process)
  end

  test "does not duplicate token buckets configuration if already present", %{
    application_file_path: application_file_path
  } do
    File.rm!(application_file_path)

    File.write!(application_file_path, """
    defmodule MagicAuthTest.Application do
      def start(_type, _args) do
        children = [
          MagicAuthTest.Repo,
          MagicAuthTestWeb.Endpoint
        ]

        children = children ++ MagicAuth.supervised_children()

        opts = [strategy: :one_for_one, name: MagicAuthTest.Supervisor]
        Supervisor.start_link(children, opts)
      end
    end
    """)

    initial_content = File.read!(application_file_path)

    capture_io(fn ->
      run([])
    end)

    final_content = File.read!(application_file_path)
    assert initial_content == final_content
  end

  test "displays error message when unable to inject token buckets configuration", %{
    application_file_path: application_file_path
  } do
    Mix.shell(Mix.Shell.IO)
    File.rm_rf!(application_file_path)

    File.write!(application_file_path, """
    defmodule MagicAuthTest.Application do
      # Different format than expected
    end
    """)

    output =
      capture_io(fn ->
        run([])
      end)

    assert output =~ "The task was unable to add some configuration to your application.ex"
    assert output =~ "You should manually add the following code to your application.ex"
  after
    Mix.shell(Mix.Shell.Process)
  end
end
