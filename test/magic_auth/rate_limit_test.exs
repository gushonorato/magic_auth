defmodule MagicAuth.RateLimitTest do
  use ExUnit.Case, async: false
  import MagicAuthTest.Helpers

  alias MagicAuth.RateLimit

  setup :preserve_app_env

  setup do
    Application.put_env(:magic_auth, :enable_rate_limit, true)
    start_supervised!(RateLimit)
    :ok
  end

  describe "check_one_time_password_request/1" do
    test "allows 1 request per email" do
      assert RateLimit.check_one_time_password_request("user@example.com") == :ok
      assert {:error, :rate_limited, countdown} = RateLimit.check_one_time_password_request("user@example.com")
      assert countdown in 1..60
    end

    test "is case insensitive" do
      assert RateLimit.check_one_time_password_request("user@example.com") == :ok
      assert {:error, :rate_limited, _countdown} = RateLimit.check_one_time_password_request("User@Example.com")
      assert {:error, :rate_limited, _countdown} = RateLimit.check_one_time_password_request("USER@EXAMPLE.COM")
    end

    test "keeps separate limits for different emails" do
      assert RateLimit.check_one_time_password_request("user1@example.com") == :ok
      assert RateLimit.check_one_time_password_request("user2@example.com") == :ok
    end

    test "always allows requests when rate limit is disabled" do
      Application.put_env(:magic_auth, :enable_rate_limit, false)

      assert RateLimit.check_one_time_password_request("user@example.com") == :ok
      assert RateLimit.check_one_time_password_request("user@example.com") == :ok
    end
  end

  describe "one_time_password_request_countdown/1" do
    test "returns 0 when a new request is allowed" do
      assert RateLimit.one_time_password_request_countdown("user@example.com") == 0
    end

    test "returns the seconds until a new request is allowed" do
      :ok = RateLimit.check_one_time_password_request("user@example.com")

      assert RateLimit.one_time_password_request_countdown("user@example.com") in 1..60
      assert RateLimit.one_time_password_request_countdown("USER@example.com") in 1..60
    end
  end
end
