defmodule E2E.Mix.Tasks.MagicAuth.InstallTest do
  use ExUnit.Case, async: false

  import MagicAuthTest.Helpers
  require Logger

  @phoenix_project "magic_auth_test"

  setup_all :use_tmp_dir

  setup_all do
    # Create a new Phoenix project with minimal dependencies
    System.cmd("mix", ["phx.new", @phoenix_project, "--no-install", "--no-dashboard", "--no-gettext", "--no-mailer"])

    # Add magic_auth dependency to the project's mix.exs
    file_contents = [@phoenix_project, "mix.exs"] |> Path.join() |> File.read!()

    file_contents =
      String.replace(
        file_contents,
        ~s({:bandit, "~> 1.5"}),
        ~s({:bandit, "~> 1.5"},\n    {:magic_auth, path: "../../../"}\n)
      )

    [@phoenix_project, "mix.exs"] |> Path.join() |> File.write!(file_contents)

    # Install project dependencies
    System.cmd("mix", ["deps.get"], cd: @phoenix_project)

    # Run the magic_auth installer
    System.cmd("mix", ["magic_auth.install"], cd: @phoenix_project)
    :ok
  end

  @tag :e2e
  test "creates magic_auth callbacks" do
    callback_file = Path.join([@phoenix_project, "lib", "magic_auth_test_web", "magic_auth.ex"])
    assert File.exists?(callback_file)
  end

  @tag :e2e
  test "injects configuration in config.exs" do
    config =
      [@phoenix_project, "config", "config.exs"]
      |> Path.join()
      |> File.read!()

    assert String.contains?(config, "config :magic_auth")
  end

  @tag :e2e
  test "creates migration file" do
    migrations = Path.join([@phoenix_project, "priv", "repo", "migrations", "*_create_magic_auth_tables.exs"])
    assert [_] = Path.wildcard(migrations)
  end

  @tag :e2e
  test "injects routes in router.ex" do
    router =
      [@phoenix_project, "lib", "#{@phoenix_project}_web", "router.ex"]
      |> Path.join()
      |> File.read!()

    assert String.contains?(router, "use MagicAuth.Router")
    assert String.contains?(router, "plug :fetch_magic_auth_session")
  end

  @tag :e2e
  test "injects code in application.ex" do
    application =
      [@phoenix_project, "lib", @phoenix_project, "application.ex"]
      |> Path.join()
      |> File.read!()

    assert String.contains?(application, "children = children ++ MagicAuth.supervised_children()")
  end

  @tag :e2e
  test "injects code in app.js" do
    app_js =
      [@phoenix_project, "assets", "js", "app.js"]
      |> Path.join()
      |> File.read!()

    assert String.contains?(app_js, ~s(import {MagicAuthHooks} from "magic_auth"))
    assert String.contains?(app_js, ~s(hooks: {...MagicAuthHooks}))
  end
end
