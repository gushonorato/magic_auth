defmodule Mix.Tasks.MagicAuth.Install do
  use Mix.Task
  import Mix.Generator
  import Mix.Phoenix

  @shortdoc "Installs Magic Auth"

  @template_dir "#{:code.priv_dir(:magic_auth)}/templates/magic_auth.install"

  def run(args) do
    args
    |> build_assigns()
    |> install()
  end

  def build_assigns(_args) do
    %{
      base: base(),
      repo_module: repo_module(),
      web_module:
        base()
        |> web_module()
        |> to_string()
        |> String.replace_prefix("Elixir.", ""),
      router_file_path: context_app() |> web_path("router.ex"),
      application_file_path: context_app() |> context_lib_path("application.ex")
    }
  end

  def repo_module() do
    context_app()
    |> Application.fetch_env!(:ecto_repos)
    |> List.first()
    |> to_string()
    |> String.replace_prefix("Elixir.", "")
  end

  def repo_path() do
    repo_module()
    |> to_string()
    |> String.replace_prefix("Elixir.", "")
    |> String.split(".")
    |> List.last()
    |> Macro.underscore()
  end

  def migrations_path(rel \\ "") do
    context_app_path(context_app(), Path.join(["priv", repo_path(), "migrations", rel]))
  end

  defp install(assigns) do
    inject_config(assigns)
    install_magic_token_migration_file(assigns)
    install_magic_auth_callbacks(assigns)
    inject_router(assigns)
    install_token_buckets(assigns)

    Mix.shell().info("""

    Magic Auth installed successfully!

    Don't forget to run the migration:
        $ mix ecto.migrate
    """)
  end

  def inject_config(_assigns) do
    config_file = Path.join(["config/config.exs"])
    Mix.shell().info(IO.ANSI.cyan() <> "* injecting " <> IO.ANSI.reset() <> "#{config_file}")

    config_content = File.read!(config_file)

    unless String.match?(config_content, ~r/config :magic_auth\b/) do
      File.write!(
        config_file,
        config_content <>
          """
          config :magic_auth,
            callbacks: #{base() |> web_module() |> to_string() |> String.replace_prefix("Elixir.", "")}.MagicAuth,
            repo: #{repo_module()},
            router: #{base() |> web_module() |> to_string() |> String.replace_prefix("Elixir.", "")}.Router,
            endpoint: #{base() |> web_module() |> to_string() |> String.replace_prefix("Elixir.", "")}.Endpoint,
            remember_me_cookie: "_#{context_app()}_remember_me"
          """
      )
    end
  end

  def install_magic_token_migration_file(assigns) do
    migration_file = migrations_path("#{generate_migration_timestamp()}_create_magic_auth_tables.exs")
    copy_template("#{@template_dir}/create_magic_auth_tables.exs.eex", migration_file, assigns)
  end

  defp generate_migration_timestamp do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
    |> String.replace(["-", ":", " "], "")
  end

  defp install_magic_auth_callbacks(assigns) do
    copy_template(
      "#{@template_dir}/magic_auth.ex.eex",
      context_app() |> web_path("magic_auth.ex"),
      assigns
    )
  end

  defp inject_router(assigns) do
    Mix.shell().info(IO.ANSI.cyan() <> "* injecting " <> IO.ANSI.reset() <> "#{assigns.router_file_path}")
    inject_use_router(assigns)
    inject_fetch_current_user_session_plug(assigns)
  end

  defp inject_use_router(assigns) do
    router_file_content = File.read!(assigns.router_file_path)

    unless check_if_use_router_already_installed(router_file_content) do
      changed_router_file_content =
        String.replace(
          router_file_content,
          ~r/use #{assigns.web_module}, :router/,
          "use #{assigns.web_module}, :router\n  use MagicAuth.Router\n\n  magic_auth()"
        )

      if router_file_content == changed_router_file_content do
        Mix.shell().info("""
        The task was unable to add some configuration to your router.ex. You should manually add the following code to your router.ex file to complete the setup:

        defmodule #{assigns.web_module}.Router do
        use #{assigns.web_module}, :router
        use MagicAuth.Router

        magic_auth()
        # ...
        end
        """)
      else
        File.write!(assigns.router_file_path, changed_router_file_content)
      end
    end
  end

  defp check_if_use_router_already_installed(router_file_content) do
    String.contains?(router_file_content, "use MagicAuth.Router")
  end

  defp inject_fetch_current_user_session_plug(assigns) do
    router_file_content = File.read!(assigns.router_file_path)

    unless fetch_current_user_session_plug_installed?(router_file_content) do
      case Regex.run(~r/pipeline :browser do(.*)end/Us, router_file_content, return: :index) do
        [{_, _}, {_, index}] ->
          changed_router_file_content =
            router_file_content
            |> String.split_at(index)
            |> Tuple.to_list()
            |> Enum.join("    plug :fetch_current_user_session\n")

          File.write!(assigns.router_file_path, changed_router_file_content)

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

  defp install_token_buckets(assigns) do
    Mix.shell().info(IO.ANSI.cyan() <> "* injecting " <> IO.ANSI.reset() <> "#{assigns.application_file_path}")
    application_file_content = File.read!(assigns.application_file_path)

    unless token_bucket_installed?(application_file_content) do
      case Regex.run(~r/children = \[.*\s\s\s\s\]\n/Us, application_file_content, return: :index) do
        [{index, length}] ->
          {prelude, postlude} = String.split_at(application_file_content, index + length)

          changed_application_file_content =
            prelude <> "    children = children ++ MagicAuth.supervised_children()\n" <> postlude

          File.write!(assigns.application_file_path, changed_application_file_content)

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
