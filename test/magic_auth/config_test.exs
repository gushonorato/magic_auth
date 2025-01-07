defmodule ConfigTest do
  use ExUnit.Case, async: true

  alias MagicAuth.Config

  setup do
    Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
    Application.put_env(:lero_lero_app, :ecto_repos, [MagicAuthTest.Repo])

    on_exit(fn ->
      Application.delete_env(:magic_auth, :otp_app)
      Application.delete_env(:lero_lero_app, :ecto_repos)
    end)

    :ok
  end

  describe "one_time_password_length/0" do
    test "returns default value when not configured" do
      Application.delete_env(:magic_auth, :one_time_password_length)
      assert Config.one_time_password_length() == 6
    end

    test "returns configured value" do
      Application.put_env(:magic_auth, :one_time_password_length, 8)
      assert Config.one_time_password_length() == 8
      Application.delete_env(:magic_auth, :one_time_password_length)
    end
  end

  describe "otp_app/0" do
    test "returns the application name correctly" do
      Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
      assert Config.otp_app() == :lero_lero_app
    end

    test "returns app from Mix config if is not set" do
      Application.delete_env(:magic_auth, :otp_app)
      assert Config.otp_app() == :magic_auth
    end
  end

  describe "otp_app_module/0" do
    test "returns the application module name correctly" do
      Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
      assert Config.otp_app_module() == LeroLeroApp
    end
  end

  describe "web_module_name/0" do
    test "returns the Web module when otp_app doesn't end with Web" do
      Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
      assert Config.web_module() === LeroLeroAppWeb
    end

    test "returns the module directly when it already ends with Web" do
      Application.put_env(:magic_auth, :otp_app, :lero_lero_app_web)
      assert Config.web_module() === LeroLeroAppWeb
    end
  end

  describe "repo_module/0" do
    test "returns the configured repo when explicitly defined" do
      Application.put_env(:magic_auth, :repo, MagicAuthTest.Repo)

      assert Config.repo_module() == MagicAuthTest.Repo

      Application.delete_env(:magic_auth, :repo)
    end

    test "fetches repo from otp_app when not explicitly configured" do
      Application.put_env(:lero_lero_app, :ecto_repos, [MagicAuthTest.AnotherRepo])

      assert Config.repo_module() == MagicAuthTest.AnotherRepo

      Application.delete_env(:lero_lero_app, :ecto_repos)
    end
  end

  describe "repo_module_name/0" do
    test "returns the repository module name as string without Elixir prefix" do
      Application.put_env(:magic_auth, :repo, MyApp.Repo)

      assert Config.repo_module_name() == "MyApp.Repo"

      Application.delete_env(:magic_auth, :repo)
    end
  end

  describe "callback_module/0" do
    test "returns the callback module when explicitly configured" do
      Application.put_env(:magic_auth, :callbacks, LeroLeroAppWeb.CustomCallback)
      assert Config.callback_module() == LeroLeroAppWeb.CustomCallback
      Application.delete_env(:magic_auth, :callbacks)
    end

    test "uses web_module as fallback when callback is not configured" do
      Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
      assert Config.callback_module() == LeroLeroAppWeb.MagicAuth
    end
  end

  describe "one_time_password_expiration/0" do
    test "returns default value when not configured" do
      Application.delete_env(:magic_auth, :one_time_password_expiration)
      assert Config.one_time_password_expiration() == 10
    end

    test "returns configured value" do
      Application.put_env(:magic_auth, :one_time_password_expiration, 15)
      assert Config.one_time_password_expiration() == 15
      Application.delete_env(:magic_auth, :one_time_password_expiration)
    end
  end

  describe "router/0" do
    test "returns the configured router when explicitly set" do
      Application.put_env(:magic_auth, :router, LeroLeroAppWeb.CustomRouter)
      assert Config.router() == LeroLeroAppWeb.CustomRouter
      Application.delete_env(:magic_auth, :router)
    end

    test "returns default router based on web_module when not configured" do
      Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
      assert Config.router() == LeroLeroAppWeb.Router
    end
  end

  describe "remember_me/0" do
    test "returns default value when not configured" do
      assert Config.remember_me() == true
    end

    test "returns configured value" do
      Application.put_env(:magic_auth, :remember_me, false)
      assert Config.remember_me() == false
      Application.delete_env(:magic_auth, :remember_me)
    end
  end

  describe "remember_me_cookie/0" do
    test "returns default cookie based on app name" do
      Application.put_env(:magic_auth, :otp_app, :my_app)
      assert Config.remember_me_cookie() == "_my_app_remember_me"
      Application.delete_env(:magic_auth, :otp_app)
    end

    test "returns configured value" do
      Application.put_env(:magic_auth, :remember_me_cookie, "_custom_cookie")
      assert Config.remember_me_cookie() == "_custom_cookie"
      Application.delete_env(:magic_auth, :remember_me_cookie)
    end
  end

  describe "session_validity_in_days/0" do
    test "returns default value when not configured" do
      assert Config.session_validity_in_days() == 60
    end

    test "returns configured value" do
      Application.put_env(:magic_auth, :session_validity_in_days, 30)
      assert Config.session_validity_in_days() == 30
      Application.delete_env(:magic_auth, :session_validity_in_days)
    end
  end
end
