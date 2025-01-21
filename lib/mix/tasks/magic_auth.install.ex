defmodule Mix.Tasks.MagicAuth.Install do
  use Mix.Task
  import Mix.Generator

  @shortdoc "Installs Magic Auth"

  @template_dir "#{:code.priv_dir(:magic_auth)}/templates/magic_auth.install"

  defp web_module do
    Mix.Phoenix.base() |> Mix.Phoenix.web_module() |> to_string() |> String.replace_prefix("Elixir.", "")
  end

  defp js_file, do: "assets/js/app.js"

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

  defp config_file() do
    if Mix.Phoenix.in_umbrella?(".") do
      Path.join(["..", "..", "config", "config.exs"])
    else
      Path.join(["config", "config.exs"])
    end
  end

  def run(_args) do
    inject_config()
    install_magic_token_migration_file()
    install_magic_auth_callbacks()
    inject_router()
    install_token_buckets()
    install_js()

    Mix.shell().info("""

    Magic Auth installed successfully!

    Don't forget to run the migration:
        $ mix ecto.migrate
    """)
  end

  def inject_config() do
    Mix.shell().info(IO.ANSI.cyan() <> "* injecting " <> IO.ANSI.reset() <> "config/config.exs")

    config_content = File.read!(config_file())

    unless String.match?(config_content, ~r/config :magic_auth\b/) do
      File.write!(
        config_file(),
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
      base: Mix.Phoenix.context_app() |> Mix.Phoenix.context_base()
    )
  end

  defp inject_router() do
    Mix.shell().info(IO.ANSI.cyan() <> "* injecting " <> IO.ANSI.reset() <> "#{router_file()}")
    inject_use_router()
    inject_fetch_magic_auth_session_plug()
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

  defp inject_fetch_magic_auth_session_plug() do
    with {:ok, router_file_content} <- File.read(router_file()),
         :not_injected <- check_if_injected(router_file_content, "plug :fetch_magic_auth_session"),
         true <- String.contains?(router_file_content, "plug :put_secure_browser_headers") do

      router_file_content = String.replace(router_file_content,
      "plug :put_secure_browser_headers",
      "plug :put_secure_browser_headers\n    plug :fetch_magic_auth_session")

      File.write!(router_file(), router_file_content)

    else
      :already_injected ->
        :ok

      _ ->
        Mix.shell().info("""
        The task was unable to add some configuration to your router.ex. You should manually add the following code to your router.ex file to complete the setup:

        pipeline :browser do
          # add this after the other plugs
          plug :fetch_magic_auth_session
        end
        """)
    end
  end


  defp install_token_buckets() do
    Mix.shell().info(IO.ANSI.cyan() <> "* injecting " <> IO.ANSI.reset() <> "#{application_file()}")
    application_file_content = File.read!(application_file())

    unless token_bucket_installed?(application_file_content) do
      case Regex.run(~r/children = \[.*\s\s\s\s\]\n/Us, application_file_content, return: :index) do
        [{index, length}] ->
          {prelude, postlude} = String.split_at(application_file_content, index + length)

          changed_application_file_content =
            prelude <> "    children = children ++ MagicAuth.children()\n" <> postlude

          File.write!(application_file(), changed_application_file_content)

        _not_found ->
          Mix.shell().info("""
          The task was unable to add some configuration to your application.ex. You should manually add the following code to your application.ex file to complete the setup:

          children = children ++ MagicAuth.children()
          """)
      end
    end
  end

  defp token_bucket_installed?(application_file_content) do
    String.contains?(application_file_content, "MagicAuth.children")
  end

  defp install_js() do
    Mix.shell().info(IO.ANSI.cyan() <> "* injecting " <> IO.ANSI.reset() <> "#{js_file()}")

    inject_js_import()
    inject_js_magic_auth_hook()
  end

  defp check_if_injected(js_file_content, content) do
    if String.contains?(js_file_content, content) do
      :already_injected
    else
      :not_injected
    end
  end

  defp inject_js_import() do
    with {:ok, js_file_content} <- File.read(js_file()),
         :not_injected <-
           check_if_injected(js_file_content, ~s(from "magic_auth")),
         true <- String.contains?(js_file_content, ~s(from "phoenix_live_view")) do
      js_file_content =
        String.replace(
          js_file_content,
          ~s(from "phoenix_live_view"\n),
          ~s(from "phoenix_live_view"\nimport {MagicAuthHooks} from "magic_auth"\n)
        )

      File.write!(js_file(), js_file_content)
    else
      :already_injected ->
        :ok

      _ ->
        Mix.shell().info("""
        The task was unable to add some configuration to your app.js. You should manually add the following code to your app.js file to complete the setup:

        import {MagicAuthHooks} from "magic_auth"
        """)
    end
  end

  defp inject_js_magic_auth_hook() do
    lookup_content = """
    let liveSocket = new LiveSocket("/live", Socket, {
      longPollFallbackMs: 2500,
      params: {_csrf_token: csrfToken}
    })
    """

    with {:ok, js_file_content} <- File.read(js_file()),
         :not_injected <- check_if_injected(js_file_content, "hooks: {...MagicAuthHooks}"),
         true <- String.contains?(js_file_content, lookup_content) do
      js_file_content =
        String.replace(
          js_file_content,
          "params: {_csrf_token: csrfToken}",
          "params: {_csrf_token: csrfToken},\n  hooks: {...MagicAuthHooks}"
        )

      File.write!(js_file(), js_file_content)
    else
      :already_injected ->
        :ok

      _ ->
        Mix.shell().info("""
        The task was unable to add some configuration to your app.js. You should manually add the following code to your app.js file to complete the setup:

        let liveSocket = new LiveSocket("/live", Socket, {
          # add this hooks in line below into your liveSocket configuration
          hooks: {...MagicAuthHooks}
        })
        """)
    end
  end
end
