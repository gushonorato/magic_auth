defmodule ConfigTest do
  use ExUnit.Case, async: true

  alias MagicAuth.Config

  setup do
    app = :lero_lero_app
    Application.put_env(:magic_auth, :otp_app, app)
    Application.put_env(:lero_lero_app, :ecto_repos, [MagicAuthTest.Repo])

    on_exit(fn ->
      Application.delete_env(:magic_auth, :otp_app)
      Application.delete_env(:lero_lero_app, :ecto_repos)
    end)

    %{app: app}
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

  describe "endpoint/0" do
    test "returns configured endpoint when explicitly set" do
      Application.put_env(:magic_auth, :endpoint, TestApp.Endpoint)

      assert MagicAuth.Config.endpoint() == TestApp.Endpoint

      Application.delete_env(:magic_auth, :endpoint)
    end

    test "returns default endpoint based on web_module when not configured" do
      Application.put_env(:magic_auth, :otp_app, :magic_auth_test)

      assert MagicAuth.Config.endpoint() == MagicAuthTestWeb.Endpoint

      Application.delete_env(:magic_auth, :otp_app)
    end
  end

  describe "rate_limit_enabled?/0" do
    test "returns true when no configuration is set" do
      Application.delete_env(:magic_auth, :enable_rate_limit)
      assert MagicAuth.Config.rate_limit_enabled?() == true
    end

    test "returns configured value when set" do
      Application.put_env(:magic_auth, :enable_rate_limit, false)
      assert MagicAuth.Config.rate_limit_enabled?() == false

      Application.put_env(:magic_auth, :enable_rate_limit, true)
      assert MagicAuth.Config.rate_limit_enabled?() == true
    end

    setup do
      on_exit(fn ->
        Application.delete_env(:magic_auth, :enable_rate_limit)
      end)
    end
  end

  describe "base/0" do
    test "returns the configured namespace when defined" do
      Application.put_env(:lero_lero_app, :namespace, MyApp.Namespace)

      assert MagicAuth.Config.base() == "MyApp.Namespace"
    after
      Application.delete_env(:lero_lero_app, :namespace)
    end

    test "returns the camelized app name when namespace is not defined" do
      assert MagicAuth.Config.base() == "LeroLeroApp"
    end
  end

  describe "web_path/2" do
    test "returns the correct web path when ctx_app is equal to the current app" do
      assert MagicAuth.Config.web_path(:lero_lero_app) == "lib/lero_lero_app_web"
      assert MagicAuth.Config.web_path(:lero_lero_app, "controllers") == "lib/lero_lero_app_web/controllers"
    end

    test "returns the correct web path when ctx_app is different from the current app" do
      assert MagicAuth.Config.web_path(:other_app) == "lib/lero_lero_app"
      assert MagicAuth.Config.web_path(:other_app, "controllers") == "lib/lero_lero_app/controllers"
    end
  end

  describe "context_app_path/2" do
    test "returns rel_path when ctx_app is equal to the current app", %{app: app} do
      assert Config.context_app_path(app, "some/path") == "some/path"
    end

    test "uses configured path when context_app is configured with a tuple", %{app: app} do
      other_app = :other_app

      Application.put_env(app, :generators, context_app: {:other_app, "apps/other_app"})
      Application.put_env(:other_app, :ecto_repos, [MagicAuthTest.Repo])

      assert Config.context_app_path(other_app, "") == "apps/other_app"
    after
      File.rm_rf!("apps/other_app")
      Application.delete_env(app, :generators)
      Application.delete_env(:other_app, :ecto_repos)
    end

    test "raises an error when ctx_app is not in the deps" do
      non_existing_app = :non_existing_app

      assert_raise Mix.Error, ~r/no directory for context_app/, fn ->
        Config.context_app_path(non_existing_app, "some/path")
      end
    end
  end
end
