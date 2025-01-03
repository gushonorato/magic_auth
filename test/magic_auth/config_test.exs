defmodule MagicAuth.ConfigTest do
  use ExUnit.Case, async: true

  setup do
    Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
    Application.put_env(:lero_lero_app, :ecto_repos, [MagicAuth.TestRepo])

    on_exit(fn ->
      Application.delete_env(:magic_auth, :otp_app)
      Application.delete_env(:lero_lero_app, :ecto_repos)
    end)

    :ok
  end

  describe "one_time_password_length/0" do
    test "returns default value when not configured" do
      Application.delete_env(:magic_auth, :one_time_password_length)
      assert MagicAuth.Config.one_time_password_length() == 6
    end

    test "returns configured value" do
      Application.put_env(:magic_auth, :one_time_password_length, 8)
      assert MagicAuth.Config.one_time_password_length() == 8
      Application.delete_env(:magic_auth, :one_time_password_length)
    end
  end

  describe "otp_app/0" do
    test "returns the application name correctly" do
      Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
      assert MagicAuth.Config.otp_app() == :lero_lero_app
    end
  end

  describe "otp_app_module/0" do
    test "returns the application module name correctly" do
      Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
      assert MagicAuth.Config.otp_app_module() == LeroLeroApp
    end
  end

  describe "web_module/0" do
    test "returns the Web module when otp_app doesn't end with Web" do
      Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
      assert MagicAuth.Config.web_module() == LeroLeroAppWeb
    end

    test "returns the module directly when it already ends with Web" do
      Application.put_env(:magic_auth, :otp_app, :lero_lero_app_web)
      assert MagicAuth.Config.web_module() == LeroLeroAppWeb
    end
  end

  describe "repo_module/0" do
    test "returns the configured repo when explicitly defined" do
      Application.put_env(:magic_auth, :repo, MagicAuth.TestRepo)

      assert MagicAuth.Config.repo_module() == MagicAuth.TestRepo

      Application.delete_env(:magic_auth, :repo)
    end

    test "fetches repo from otp_app when not explicitly configured" do
      Application.put_env(:lero_lero_app, :ecto_repos, [MagicAuth.TestRepo2])

      assert MagicAuth.Config.repo_module() == MagicAuth.TestRepo2

      Application.delete_env(:lero_lero_app, :ecto_repos)
    end
  end

  describe "callback_module/0" do
    test "returns the callback module when explicitly configured" do
      Application.put_env(:magic_auth, :callbacks, LeroLeroAppWeb.CustomCallback)
      assert MagicAuth.Config.callback_module() == LeroLeroAppWeb.CustomCallback
      Application.delete_env(:magic_auth, :callbacks)
    end

    test "uses web_module as fallback when callback is not configured" do
      Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
      assert MagicAuth.Config.callback_module() == LeroLeroAppWeb.MagicAuth
    end
  end

  describe "one_time_password_expiration/0" do
    test "returns default value when not configured" do
      Application.delete_env(:magic_auth, :one_time_password_expiration)
      assert MagicAuth.Config.one_time_password_expiration() == 10
    end

    test "returns configured value" do
      Application.put_env(:magic_auth, :one_time_password_expiration, 15)
      assert MagicAuth.Config.one_time_password_expiration() == 15
      Application.delete_env(:magic_auth, :one_time_password_expiration)
    end
  end
end
