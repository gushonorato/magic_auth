defmodule MagicAuth.Config do
  @moduledoc false
  def one_time_password_length, do: Application.get_env(:magic_auth, :one_time_password_length, 6)
  def one_time_password_expiration, do: Application.get_env(:magic_auth, :one_time_password_expiration, 10)

  def repo_module do
    Application.fetch_env!(:magic_auth, :repo)
  end

  def callback_module do
    Application.fetch_env!(:magic_auth, :callbacks)
  end

  def router() do
    Application.fetch_env!(:magic_auth, :router)
  end

  def remember_me do
    Application.get_env(:magic_auth, :remember_me, true)
  end

  def remember_me_cookie do
    Application.fetch_env!(:magic_auth, :remember_me_cookie)
  end

  def session_validity_in_days do
    Application.get_env(:magic_auth, :session_validity_in_days, 60)
  end

  def endpoint() do
    Application.fetch_env!(:magic_auth, :endpoint)
  end

  def rate_limit_enabled? do
    Application.get_env(:magic_auth, :enable_rate_limit, true)
  end

  def user_schema do
    Application.fetch_env!(:magic_auth, :user_schema)
  end
end
