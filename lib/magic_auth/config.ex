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

  def otp_app_module do
    module = otp_app() |> Atom.to_string() |> Phoenix.Naming.camelize()
    Module.concat([module])
  end

  def web_module do
    if otp_app_module() |> to_string() |> String.ends_with?("Web") do
      Module.concat([otp_app_module()])
    else
      Module.concat(["#{otp_app_module()}Web"])
    end
  end

  def web_module_name() do
    web_module() |> to_string() |> String.replace_prefix("Elixir.", "")
  end

  def repo_module do
    Application.get_env(:magic_auth, :repo) || Application.fetch_env!(otp_app(), :ecto_repos) |> List.first()
  end

  def repo_module_name do
    repo_module() |> to_string() |> String.replace_prefix("Elixir.", "")
  end

  def callback_module do
    case Application.get_env(:magic_auth, :callbacks) do
      nil ->
        Module.concat([web_module(), "MagicAuth"])

      module ->
        module
    end
  end

  def router() do
    Application.get_env(:magic_auth, :router) || Module.concat([web_module_name(), "Router"])
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
end
