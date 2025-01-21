defmodule E2E.Mix.Tasks.MagicAuth.InstallUmbrellaTest do
  use ExUnit.Case, async: false

  import MagicAuthTest.Helpers

  @project_name "magic_auth_test"
  @umbrella_path "#{@project_name}_umbrella"
  @web_project_name "#{@project_name}_web"
  @web_project_path Path.join([@umbrella_path, "apps", @web_project_name])
  @context_project_path Path.join([@umbrella_path, "apps", @project_name])

  setup_all :use_tmp_dir

  setup_all do
    # Create a new Phoenix umbrella project with minimal dependencies
    System.cmd("mix", [
      "phx.new",
      @project_name,
      "--umbrella",
      "--no-install",
      "--no-dashboard",
      "--no-gettext",
      "--no-mailer"
    ])

    # Add magic_auth dependency to the web project's mix.exs
    mix_file = Path.join([@web_project_path, "mix.exs"])

    file_contents =
      mix_file
      |> File.read!()
      |> String.replace(~s({:bandit, "~> 1.5"}), ~s({:bandit, "~> 1.5"},\n    {:magic_auth, path: "../../../../../"}\n))

    File.write!(mix_file, file_contents)

    # Install dependencies in the umbrella project
    System.cmd("mix", ["deps.get"], cd: @umbrella_path)

    # Run magic_auth installation task in the web project
    System.cmd("mix", ["magic_auth.install"], cd: @web_project_path)
    :ok
  end

  @tag :e2e
  test "creates magic_auth callbacks" do
    callback_file = Path.join([@web_project_path, "lib", @web_project_name, "magic_auth.ex"])
    assert File.exists?(callback_file)
  end

  @tag :e2e
  test "injects configuration in config.exs" do
    config =
      [@umbrella_path, "config", "config.exs"]
      |> Path.join()
      |> File.read!()

    assert String.contains?(config, "config :magic_auth")
  end

  @tag :e2e
  test "creates migration file" do
    migrations = Path.join([@context_project_path, "priv", "repo", "migrations", "*_create_magic_auth_tables.exs"])
    assert [_] = Path.wildcard(migrations)
  end

  @tag :e2e
  test "injects routes in router.ex" do
    router =
      [@web_project_path, "lib", @web_project_name, "router.ex"]
      |> Path.join()
      |> File.read!()

    assert String.contains?(router, "use MagicAuth.Router")
    assert String.contains?(router, "plug :fetch_magic_auth_session")
  end

  @tag :e2e
  test "injects code in application.ex" do
    application =
      [@context_project_path, "lib", @project_name, "application.ex"]
      |> Path.join()
      |> File.read!()

    assert String.contains?(application, "children = children ++ MagicAuth.supervised_children()")
  end

  @tag :e2e
  test "injects code in app.js" do
    app_js =
      [@web_project_path, "assets", "js", "app.js"]
      |> Path.join()
      |> File.read!()

    assert String.contains?(app_js, ~s(import {MagicAuthHooks} from "magic_auth"))
    assert String.contains?(app_js, ~s(hooks: {...MagicAuthHooks}))
  end
end
