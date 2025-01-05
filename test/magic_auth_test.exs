defmodule MagicAuthTest do
  use MagicAuth.DataCase, async: true

  import Mox

  alias MagicAuth.OneTimePassword

  setup :verify_on_exit!

  doctest MagicAuth, except: [create_one_time_password: 1]

  setup do
    Application.put_env(:magic_auth, :otp_app, :lero_lero_app)
    Application.put_env(:lero_lero_app, :ecto_repos, [MagicAuth.TestRepo])
    Application.put_env(:magic_auth, :callbacks, MagicAuth.CallbacksMock)

    Mox.stub(MagicAuth.CallbacksMock, :on_one_time_password_requested, fn _code, _one_time_password -> :ok end)

    on_exit(fn ->
      Application.delete_env(:magic_auth, :otp_app)
      Application.delete_env(:lero_lero_app, :ecto_repos)
      Application.delete_env(:magic_auth, :callbacks)
    end)

    :ok
  end

  describe "create_one_time_password/1" do
    test "generates valid one-time password with valid email" do
      email = "user@example.com"
      {:ok, token} = MagicAuth.create_one_time_password(%{"email" => email})

      assert token.email == email
      assert String.length(token.hashed_password) > 0
    end

    test "returns error with invalid email" do
      {:error, changeset} = MagicAuth.create_one_time_password(%{"email" => "invalid_email"})
      assert "has invalid format" in errors_on(changeset).email
    end

    test "removes existing tokens before creating a new one" do
      email = "user@example.com"
      {:ok, _token1} = MagicAuth.create_one_time_password(%{"email" => email})
      {:ok, token2} = MagicAuth.create_one_time_password(%{"email" => email})

      tokens = MagicAuth.TestRepo.all(OneTimePassword)
      assert length(tokens) == 1
      assert List.first(tokens).id == token2.id
    end

    test "does not remove one-time passwords from other emails" do
      email1 = "user1@example.com"
      email2 = "user2@example.com"

      {:ok, one_time_password1} = MagicAuth.create_one_time_password(%{"email" => email1})
      {:ok, one_time_password2} = MagicAuth.create_one_time_password(%{"email" => email2})
      {:ok, new_one_time_password1} = MagicAuth.create_one_time_password(%{"email" => email1})

      one_time_passwords = MagicAuth.TestRepo.all(OneTimePassword)
      assert length(one_time_passwords) == 2
      assert Enum.any?(one_time_passwords, fn s -> s.id == one_time_password2.id end)
      assert Enum.any?(one_time_passwords, fn s -> s.id == new_one_time_password1.id end)
      refute Enum.any?(one_time_passwords, fn s -> s.id == one_time_password1.id end)
    end

    test "stores token value as bcrypt hash" do
      {:ok, token} = MagicAuth.create_one_time_password(%{"email" => "user@example.com"})

      # Verify hashed_password starts with "$2b$" which is the bcrypt hash identifier
      assert String.starts_with?(token.hashed_password, "$2b$")
      # Verify hashed_password length is correct (60 characters)
      assert String.length(token.hashed_password) == 60
    end

    test "calls on_one_time_password_requested callback" do
      email = "user@example.com"

      expect(MagicAuth.CallbacksMock, :on_one_time_password_requested, fn _code, on_time_password ->
        assert on_time_password.email == email
        :ok
      end)

      {:ok, _token} = MagicAuth.create_one_time_password(%{"email" => email})
    end
  end

  describe "verify_password/2" do
    test "returns ok when password is correct and within expiration time" do
      email = "test@example.com"
      # assuming one_time_password_length is 6
      password = "123456"
      hashed_password = Bcrypt.hash_pwd_salt(password)

      # Create a valid one_time_password
      one_time_password =
        %OneTimePassword{
          email: email,
          hashed_password: hashed_password,
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
        |> MagicAuth.Config.repo_module().insert!()

      assert {:ok, returned_one_time_password} = MagicAuth.verify_password(email, password)
      assert returned_one_time_password.id == one_time_password.id
    end

    test "returns error when password is expired" do
      email = "test@example.com"
      password = "123456"
      hashed_password = Bcrypt.hash_pwd_salt(password)

      # Create a one_time_password with old timestamp
      expired_time =
        DateTime.utc_now()
        # 11 minutes in the past
        |> DateTime.add(-11, :minute)
        |> DateTime.truncate(:second)

      %OneTimePassword{
        email: email,
        hashed_password: hashed_password,
        inserted_at: expired_time
      }
      |> MagicAuth.Config.repo_module().insert!()

      assert {:error, :code_expired} = MagicAuth.verify_password(email, password)
    end

    test "returns ok when password is within custom expiration time" do
      email = "test@example.com"
      password = "123456"
      hashed_password = Bcrypt.hash_pwd_salt(password)

      # Configura tempo de expiração para 50 minutos
      Application.put_env(:magic_auth, :one_time_password_expiration, 50)

      # Cria uma sessão com timestamp de 45 minutos atrás
      past_time =
        DateTime.utc_now()
        |> DateTime.add(-45, :minute)
        |> DateTime.truncate(:second)

      one_time_password =
        %OneTimePassword{
          email: email,
          hashed_password: hashed_password,
          inserted_at: past_time
        }
        |> MagicAuth.Config.repo_module().insert!()

      assert {:ok, returned_one_time_password} = MagicAuth.verify_password(email, password)
      assert returned_one_time_password.id == one_time_password.id

      # Restaura configuração padrão
      Application.put_env(:magic_auth, :one_time_password_expiration, 10)
    end

    test "returns error when password is incorrect" do
      email = "test@example.com"
      correct_password = "123456"
      wrong_password = "654321"
      hashed_password = Bcrypt.hash_pwd_salt(correct_password)

      # Create a valid one_time_password
      %OneTimePassword{
        email: email,
        hashed_password: hashed_password,
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
      |> MagicAuth.Config.repo_module().insert!()

      assert {:error, :invalid_code} = MagicAuth.verify_password(email, wrong_password)
    end

    test "returns error when email does not exist" do
      assert {:error, :invalid_code} = MagicAuth.verify_password("nonexistent@example.com", "123456")
    end
  end

  describe "one_time_password_length/0" do
    test "verifies default password length of 8 digits" do
      # Configure password length to 8 digits
      Application.put_env(:magic_auth, :one_time_password_length, 8)

      email = "test@example.com"
      password = "12345678"
      hashed_password = Bcrypt.hash_pwd_salt(password)

      one_time_password =
        %OneTimePassword{
          email: email,
          hashed_password: hashed_password,
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
        |> MagicAuth.Config.repo_module().insert!()

      assert {:ok, returned_one_time_password} = MagicAuth.verify_password(email, password)
      assert returned_one_time_password.id == one_time_password.id

      # Restore default configuration
      Application.put_env(:magic_auth, :one_time_password_length, 6)
    end
  end
end
