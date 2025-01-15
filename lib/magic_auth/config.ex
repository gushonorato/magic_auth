defmodule MagicAuth.Config do
  def one_time_password_length, do: Application.get_env(:magic_auth, :one_time_password_length, 6)
  def one_time_password_expiration, do: Application.get_env(:magic_auth, :one_time_password_expiration, 10)

  def otp_app do
    case Application.get_env(:magic_auth, :otp_app) do
      nil ->
        if Code.ensure_loaded?(Mix) do
          Mix.Project.config() |> Keyword.fetch!(:app)
        else
          raise "Could not determine otp_app. Configure it in config.exs:\n\nconfig :magic_auth, otp_app: :your_app"
        end

      otp_app ->
        otp_app
    end
  end

  @doc """
  Returns the module base name based on the configuration value.

      config :my_app
        namespace: My.App

  """
  def base do
    app_base(otp_app())
  end

  @doc """
  Returns the context module base name based on the configuration value.

      config :my_app
        namespace: My.App

  """
  def context_base(ctx_app) do
    app_base(ctx_app)
  end

  defp app_base(app) do
    case Application.get_env(app, :namespace, app) do
      ^app -> app |> to_string() |> Phoenix.Naming.camelize()
      mod -> mod |> inspect()
    end
  end

  @doc """
  Returns the web prefix to be used in generated file specs.
  """
  def web_path(ctx_app, rel_path \\ "") when is_atom(ctx_app) do
    this_app = otp_app()

    if ctx_app == this_app do
      Path.join(["lib", "#{this_app}_web", rel_path])
    else
      Path.join(["lib", to_string(this_app), rel_path])
    end
  end

  @doc """
  Returns the context app path prefix to be used in generated context files.
  """
  def context_app_path(ctx_app, rel_path) when is_atom(ctx_app) do
    this_app = otp_app()

    if ctx_app == this_app do
      rel_path
    else
      app_path =
        case Application.get_env(this_app, :generators)[:context_app] do
          {^ctx_app, path} -> Path.relative_to_cwd(path)
          _ -> mix_app_path(ctx_app, this_app)
        end

      Path.join(app_path, rel_path)
    end
  end

  @doc """
  Returns the context lib path to be used in generated context files.
  """
  def context_lib_path(ctx_app, rel_path) when is_atom(ctx_app) do
    context_app_path(ctx_app, Path.join(["lib", to_string(ctx_app), rel_path]))
  end

  @doc """
  Returns the context test path to be used in generated context files.
  """
  def context_test_path(ctx_app, rel_path) when is_atom(ctx_app) do
    context_app_path(ctx_app, Path.join(["test", to_string(ctx_app), rel_path]))
  end

  @doc """
  Returns the OTP context app.
  """
  def context_app do
    this_app = otp_app()

    case fetch_context_app(this_app) do
      {:ok, app} -> app
      :error -> this_app
    end
  end

  @doc """
  Returns the test prefix to be used in generated file specs.
  """
  def web_test_path(ctx_app, rel_path \\ "") when is_atom(ctx_app) do
    this_app = otp_app()

    if ctx_app == this_app do
      Path.join(["test", "#{this_app}_web", rel_path])
    else
      Path.join(["test", to_string(this_app), rel_path])
    end
  end

  defp fetch_context_app(this_otp_app) do
    case Application.get_env(this_otp_app, :generators)[:context_app] do
      nil ->
        :error

      false ->
        Mix.raise("""
        no context_app configured for current application #{this_otp_app}.

        Add the context_app generators config in config.exs:

            config :#{this_otp_app}, :generators,
              context_app: :some_app
        """)

      {app, _path} ->
        {:ok, app}

      app ->
        {:ok, app}
    end
  end

  defp mix_app_path(app, this_otp_app) do
    case Mix.Project.deps_paths() do
      %{^app => path} ->
        Path.relative_to_cwd(path)

      deps ->
        Mix.raise("""
        no directory for context_app #{inspect(app)} found in #{this_otp_app}'s deps.

        Ensure you have listed #{inspect(app)} as an in_umbrella dependency in mix.exs:

            def deps do
              [
                {:#{app}, in_umbrella: true},
                ...
              ]
            end

        Existing deps:

            #{inspect(Map.keys(deps))}

        """)
    end
  end

  @doc """
  Returns the web module prefix.
  """
  def web_module(base) do
    if base |> to_string() |> String.ends_with?("Web") do
      Module.concat([base])
    else
      Module.concat(["#{base}Web"])
    end
  end

  def repo_module do
    Application.get_env(:magic_auth, :repo) || Application.fetch_env!(context_app(), :ecto_repos) |> List.first()
  end

  def migrations_path(rel \\ "") do
    repo_path =
      repo_module()
      |> to_string()
      |> String.replace_prefix("Elixir.", "")
      |> String.split(".")
      |> List.last()
      |> Macro.underscore()

    context_app_path(context_app(), Path.join(["priv", repo_path, "migrations", rel]))
  end

  def callback_module do
    case Application.get_env(:magic_auth, :callbacks) do
      nil ->
        Module.concat([web_module(base()), "MagicAuth"])

      module ->
        module
    end
  end

  def router() do
    Application.get_env(:magic_auth, :router) || Module.concat([web_module(base()), "Router"])
  end

  def remember_me do
    Application.get_env(:magic_auth, :remember_me, true)
  end

  def remember_me_cookie do
    app_name = otp_app() |> Atom.to_string() |> Macro.underscore()
    Application.get_env(:magic_auth, :remember_me_cookie, "_#{app_name}_remember_me")
  end

  def session_validity_in_days do
    Application.get_env(:magic_auth, :session_validity_in_days, 60)
  end

  def endpoint() do
    Application.get_env(:magic_auth, :endpoint) || Module.concat([web_module(base()), "Endpoint"])
  end

  def rate_limit_enabled? do
    Application.get_env(:magic_auth, :enable_rate_limit, true)
  end
end
