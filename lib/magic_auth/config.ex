defmodule MagicAuth.Config do
  def one_time_password_length, do: Application.get_env(:magic_auth, :one_time_password_length, 6)
  def one_time_password_expiration, do: Application.get_env(:magic_auth, :one_time_password_expiration, 10)

  def otp_app, do: Application.fetch_env!(:magic_auth, :otp_app)

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

  def repo_module do
    Application.get_env(:magic_auth, :repo) || Application.fetch_env!(otp_app(), :ecto_repos) |> List.first()
  end

  def callback_module do
    case Application.get_env(:magic_auth, :callbacks) do
      nil ->
        Module.concat([web_module(), "MagicAuth"])

      module ->
        module
    end
  end
end
