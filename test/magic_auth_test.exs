defmodule MagicAuthTest do
  use MagicAuth.DataCase, async: true
  doctest MagicAuth, except: [generate_one_time_password: 1]

  alias MagicAuth.Token

  describe "one_time_password_length/0" do
    test "returns default value when not configured" do
      Application.delete_env(:magic_auth, :one_time_password_length)
      assert MagicAuth.one_time_password_length() == 6
    end

    test "returns configured value" do
      Application.put_env(:magic_auth, :one_time_password_length, 8)
      assert MagicAuth.one_time_password_length() == 8
      Application.delete_env(:magic_auth, :one_time_password_length)
    end
  end

  describe "one_time_password_expiration/0" do
    test "returns default value when not configured" do
      Application.delete_env(:magic_auth, :one_time_password_expiration)
      assert MagicAuth.one_time_password_expiration() == 10
    end

    test "returns configured value" do
      Application.put_env(:magic_auth, :one_time_password_expiration, 15)
      assert MagicAuth.one_time_password_expiration() == 15
      Application.delete_env(:magic_auth, :one_time_password_expiration)
    end
  end

  describe "generate_one_time_password/1" do
    test "generates valid one-time password with valid email" do
      email = "user@example.com"
      {:ok, token} = MagicAuth.generate_one_time_password(%{"email" => email, "value" => "123456"})

      assert token.email == email
      assert String.length(token.value) > 0
    end

    test "returns error with invalid email" do
      {:error, changeset} = MagicAuth.generate_one_time_password(%{"email" => "invalid_email", "value" => "123456"})
      assert "has invalid format" in errors_on(changeset).email
    end

    test "removes existing tokens before creating a new one" do
      email = "user@example.com"
      {:ok, _token1} = MagicAuth.generate_one_time_password(%{"email" => email, "value" => "123456"})
      {:ok, token2} = MagicAuth.generate_one_time_password(%{"email" => email, "value" => "654321"})

      tokens = MagicAuth.TestRepo.all(Token)
      assert length(tokens) == 1
      assert List.first(tokens).id == token2.id
    end

    test "stores token value as bcrypt hash" do
      {:ok, token} = MagicAuth.generate_one_time_password(%{"email" => "user@example.com", "value" => "123456test"})

      # Verify value starts with "$2b$" which is the bcrypt hash identifier
      assert String.starts_with?(token.value, "$2b$")
      # Verify hash length is correct (60 characters)
      assert String.length(token.value) == 60
    end
  end
end
