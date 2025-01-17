defmodule ConfigTest do
  use ExUnit.Case, async: true

  alias MagicAuth.Config
  import MagicAuthTest.Helpers

  describe "one_time_password_length/0" do
    test "returns default value when not configured" do
      config_sandbox(fn ->
        Application.delete_env(:magic_auth, :one_time_password_length)
        assert Config.one_time_password_length() == 6
      end)
    end

    test "returns configured value" do
      config_sandbox(fn ->
        Application.put_env(:magic_auth, :one_time_password_length, 8)
        assert Config.one_time_password_length() == 8
      end)
    end
  end

  describe "repo_module/0" do
    test "returns the configured repo when explicitly defined" do
      config_sandbox(fn ->
        Application.put_env(:magic_auth, :repo, MagicAuthTest.AnotherRepo)
        assert Config.repo_module() == MagicAuthTest.AnotherRepo
      end)
    end
  end

  describe "callback_module/0" do
    test "returns the callback module when explicitly configured" do
      config_sandbox(fn ->
        Application.put_env(:magic_auth, :callbacks, LeroLeroAppWeb.CustomCallback)
        assert Config.callback_module() == LeroLeroAppWeb.CustomCallback
      end)
    end
  end

  describe "one_time_password_expiration/0" do
    test "returns default value when not configured" do
      config_sandbox(fn ->
        Application.delete_env(:magic_auth, :one_time_password_expiration)
        assert Config.one_time_password_expiration() == 10
      end)
    end

    test "returns configured value" do
      config_sandbox(fn ->
        Application.put_env(:magic_auth, :one_time_password_expiration, 15)
        assert Config.one_time_password_expiration() == 15
      end)
    end
  end

  describe "router/0" do
    test "returns the configured router when explicitly set" do
      config_sandbox(fn ->
        Application.put_env(:magic_auth, :router, LeroLeroAppWeb.CustomRouter)
        assert Config.router() == LeroLeroAppWeb.CustomRouter
      end)
    end
  end

  describe "remember_me/0" do
    test "returns default value when not configured" do
      assert Config.remember_me() == true
    end

    test "returns configured value" do
      config_sandbox(fn ->
        Application.put_env(:magic_auth, :remember_me, false)
        assert Config.remember_me() == false
      end)
    end
  end

  describe "remember_me_cookie/0" do
    test "returns configured value" do
      config_sandbox(fn ->
        Application.put_env(:magic_auth, :remember_me_cookie, "_custom_cookie")
        assert Config.remember_me_cookie() == "_custom_cookie"
      end)
    end
  end

  describe "session_validity_in_days/0" do
    test "returns default value when not configured" do
      assert Config.session_validity_in_days() == 60
    end

    test "returns configured value" do
      config_sandbox(fn ->
        Application.put_env(:magic_auth, :session_validity_in_days, 30)
        assert Config.session_validity_in_days() == 30
      end)
    end
  end

  describe "endpoint/0" do
    test "returns configured endpoint when explicitly set" do
      config_sandbox(fn ->
        Application.put_env(:magic_auth, :endpoint, TestApp.Endpoint)
        assert Config.endpoint() == TestApp.Endpoint
      end)
    end
  end

  describe "rate_limit_enabled?/0" do
    test "returns true when no configuration is set" do
      config_sandbox(fn ->
        Application.delete_env(:magic_auth, :enable_rate_limit)
        assert Config.rate_limit_enabled?() == true
      end)
    end

    test "returns configured value when set" do
      config_sandbox(fn ->
        Application.put_env(:magic_auth, :enable_rate_limit, false)
        assert MagicAuth.Config.rate_limit_enabled?() == false

        Application.put_env(:magic_auth, :enable_rate_limit, true)
        assert MagicAuth.Config.rate_limit_enabled?() == true
      end)
    end
  end
end
