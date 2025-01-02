defmodule MagicAuthTest do
  use MagicAuth.DataCase, async: true
  doctest MagicAuth, except: [generate_one_time_password: 1]

  alias MagicAuth.OneTimePassword

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
      {:ok, token} = MagicAuth.generate_one_time_password(%{"email" => email})

      assert token.email == email
      assert String.length(token.hashed_password) > 0
    end

    test "returns error with invalid email" do
      {:error, changeset} = MagicAuth.generate_one_time_password(%{"email" => "invalid_email"})
      assert "has invalid format" in errors_on(changeset).email
    end

    test "removes existing tokens before creating a new one" do
      email = "user@example.com"
      {:ok, _token1} = MagicAuth.generate_one_time_password(%{"email" => email})
      {:ok, token2} = MagicAuth.generate_one_time_password(%{"email" => email})

      tokens = MagicAuth.TestRepo.all(OneTimePassword)
      assert length(tokens) == 1
      assert List.first(tokens).id == token2.id
    end

    test "stores token value as bcrypt hash" do
      {:ok, token} = MagicAuth.generate_one_time_password(%{"email" => "user@example.com"})

      # Verify hashed_password starts with "$2b$" which is the bcrypt hash identifier
      assert String.starts_with?(token.hashed_password, "$2b$")
      # Verify hashed_password length is correct (60 characters)
      assert String.length(token.hashed_password) == 60
    end
  end
end
