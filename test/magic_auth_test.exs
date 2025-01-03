defmodule MagicAuthTest do
  use MagicAuth.DataCase, async: true

  import Mox

  alias MagicAuth.OneTimePassword

  setup :verify_on_exit!

  doctest MagicAuth, except: [generate_one_time_password: 1]

  setup do
    Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
    Application.put_env(:lero_lero_app, :ecto_repos, [MagicAuth.TestRepo])
    Application.put_env(:magic_auth, :callbacks, MagicAuth.CallbacksMock)

    Mox.stub(MagicAuth.CallbacksMock, :on_one_time_password_generated, fn _code, _one_time_password -> :ok end)

    on_exit(fn ->
      Application.delete_env(:magic_auth, :otp_app)
      Application.delete_env(:lero_lero_app, :ecto_repos)
      Application.delete_env(:magic_auth, :callbacks)
    end)

    :ok
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

    test "calls on_one_time_password_generated callback" do
      email = "user@example.com"

      expect(MagicAuth.CallbacksMock, :on_one_time_password_generated, fn _code, on_time_password ->
        assert on_time_password.email == email
        :ok
      end)

      {:ok, _token} = MagicAuth.generate_one_time_password(%{"email" => email})
    end
  end
end
