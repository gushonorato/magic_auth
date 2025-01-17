defmodule Mix.Tasks.MagicAuth.Install do
  use Mix.Task
  import Mix.Generator

  @shortdoc "Installs Magic Auth"

  @template_dir "#{:code.priv_dir(:magic_auth)}/templates/magic_auth.install"

  defp web_module do
    Mix.Phoenix.base() |> Mix.Phoenix.web_module() |> to_string() |> String.replace_prefix("Elixir.", "")
  end

  defp callbacks_module do
    Mix.Phoenix.base()
    |> Mix.Phoenix.web_module()
    |> to_string()
    |> String.replace_prefix("Elixir.", "")
    |> then(&"#{&1}.MagicAuth")
  end

  defp router_module do
    Mix.Phoenix.base()
    |> Mix.Phoenix.web_module()
    |> to_string()
    |> String.replace_prefix("Elixir.", "")
    |> then(&"#{&1}.Router")
  end

  defp endpoint_module do
    Mix.Phoenix.base()
    |> Mix.Phoenix.web_module()
    |> to_string()
    |> String.replace_prefix("Elixir.", "")
    |> then(&"#{&1}.Endpoint")
  end

  defp repo_module do
    Mix.Phoenix.context_app()
    |> Application.fetch_env!(:ecto_repos)
    |> List.first()
    |> to_string()
    |> String.replace_prefix("Elixir.", "")
  end

  defp repo_path do
    repo_module()
    |> to_string()
    |> String.replace_prefix("Elixir.", "")
    |> String.split(".")
    |> List.last()
    |> Macro.underscore()
  end

  defp router_file(), do: Mix.Phoenix.context_app() |> Mix.Phoenix.web_path("router.ex")

  defp application_file, do: Mix.Phoenix.context_app() |> Mix.Phoenix.context_lib_path("application.ex")
  defp remember_me_cookie, do: "_#{Mix.Phoenix.context_app()}_remember_me"

  defp migration_file() do
    file = "#{generate_migration_timestamp()}_create_magic_auth_tables.exs"
    Mix.Phoenix.context_app_path(Mix.Phoenix.context_app(), Path.join(["priv", repo_path(), "migrations", file]))
  end

  def run(_args) do
    inject_config()
    install_magic_token_migration_file()
    install_magic_auth_callbacks()
    inject_router()
    install_token_buckets()

    Mix.shell().info("""

    Magic Auth installed successfully!

    Don't forget to run the migration:
        $ mix ecto.migrate
    """)
  end

  def inject_config() do
    config_file = Path.join(["config/config.exs"])
    Mix.shell().info(IO.ANSI.cyan() <> "* injecting " <> IO.ANSI.reset() <> "#{config_file}")

    config_content = File.read!(config_file)

    unless String.match?(config_content, ~r/config :magic_auth\b/) do
      File.write!(
        config_file,
        config_content <>
          """
          config :magic_auth,
            callbacks: #{callbacks_module()},
            repo: #{repo_module()},
            router: #{router_module()},
            endpoint: #{endpoint_module()},
            remember_me_cookie: "#{remember_me_cookie()}"
          """
      )
    end
  end

  def install_magic_token_migration_file() do
    copy_template("#{@template_dir}/create_magic_auth_tables.exs.eex", migration_file(), repo_module: repo_module())
  end

  defp generate_migration_timestamp do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
    |> String.replace(["-", ":", " "], "")
  end

  defp install_magic_auth_callbacks() do
    copy_template(
      "#{@template_dir}/magic_auth.ex.eex",
      Mix.Phoenix.context_app() |> Mix.Phoenix.web_path("magic_auth.ex"),
      web_module: web_module(),
      base: Mix.Phoenix.base()
    )
  end

  defp inject_router() do
    Mix.shell().info(IO.ANSI.cyan() <> "* injecting " <> IO.ANSI.reset() <> "#{router_file()}")
    inject_use_router()
    inject_fetch_current_user_session_plug()
  end

  defp inject_use_router() do
    router_file_content = File.read!(router_file())

    unless check_if_use_router_already_installed(router_file_content) do
      changed_router_file_content =
        String.replace(
          router_file_content,
          ~r/use #{web_module()}, :router/,
          "use #{web_module()}, :router\n  use MagicAuth.Router\n\n  magic_auth()"
        )

      if router_file_content == changed_router_file_content do
        Mix.shell().info("""
        The task was unable to add some configuration to your router.ex. You should manually add the following code to your router.ex file to complete the setup:

        defmodule #{web_module()}.Router do
        use #{web_module()}, :router
        use MagicAuth.Router

        magic_auth()
        # ...
        end
        """)
      else
        File.write!(router_file(), changed_router_file_content)
      end
    end
  end

  defp check_if_use_router_already_installed(router_file_content) do
    String.contains?(router_file_content, "use MagicAuth.Router")
  end

  defp inject_fetch_current_user_session_plug() do
    router_file_content = File.read!(router_file())

    unless fetch_current_user_session_plug_installed?(router_file_content) do
      case Regex.run(~r/pipeline :browser do(.*)end/Us, router_file_content, return: :index) do
        [{_, _}, {_, index}] ->
          changed_router_file_content =
            router_file_content
            |> String.split_at(index)
            |> Tuple.to_list()
            |> Enum.join("    plug :fetch_current_user_session\n")

          File.write!(router_file(), changed_router_file_content)

        _not_found ->
          Mix.shell().info("""
          The task was unable to add some configuration to your router.ex. You should manually add the following code to your router.ex file to complete the setup:

          pipeline :browser do
            # add this after the other plugs
            plug :fetch_current_user_session
          end
          """)
      end
    end
  end

  def fetch_current_user_session_plug_installed?(router_file_content) do
    String.contains?(router_file_content, "plug :fetch_current_user_session")
  end

  defp install_token_buckets() do
    Mix.shell().info(IO.ANSI.cyan() <> "* injecting " <> IO.ANSI.reset() <> "#{application_file()}")
    application_file_content = File.read!(application_file())

    unless token_bucket_installed?(application_file_content) do
      case Regex.run(~r/children = \[.*\s\s\s\s\]\n/Us, application_file_content, return: :index) do
        [{index, length}] ->
          {prelude, postlude} = String.split_at(application_file_content, index + length)

          changed_application_file_content =
            prelude <> "    children = children ++ MagicAuth.supervised_children()\n" <> postlude

          File.write!(application_file(), changed_application_file_content)

        _not_found ->
          Mix.shell().info("""
          The task was unable to add some configuration to your application.ex. You should manually add the following code to your application.ex file to complete the setup:

          children = [
            # add this after the other children
            MagicAuth.TokenBuckets.OneTimePasswordRequestTokenBucket,
            MagicAuth.TokenBuckets.LoginAttemptTokenBucket,
          ]
          """)
      end
    end
  end

  defp token_bucket_installed?(application_file_content) do
    String.contains?(application_file_content, "MagicAuth.supervised_children")
  end
end
