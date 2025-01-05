defmodule MagicAuth.SessionTest do
  use MagicAuth.DataCase
  alias MagicAuth.Session

  describe "changeset/2" do
    test "creates a valid changeset with correct attributes" do
      attrs = %{email: "usuario@exemplo.com"}
      changeset = Session.changeset(%Session{}, attrs)
      assert changeset.valid?
    end

    test "returns error when email is missing" do
      attrs = %{}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).email
    end

    test "returns error for invalid email format" do
      attrs = %{email: "invalid_mail"}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert "has invalid format" in errors_on(changeset).email
    end
  end

  describe "generate_code/0" do
    test "generates code with correct length" do
      code = Session.generate_code()
      assert String.length(code) == MagicAuth.Config.one_time_password_length()
    end

    test "generates code with custom length when configured" do
      Application.put_env(:magic_auth, :one_time_password_length, 8)
      code = Session.generate_code()
      assert String.length(code) == 8
      Application.put_env(:magic_auth, :one_time_password_length, 6)
    end

    test "generates only numeric digits" do
      code = Session.generate_code()
      assert String.match?(code, ~r/^\d+$/)
    end

    test "generates different codes on consecutive calls" do
      code1 = Session.generate_code()
      code2 = Session.generate_code()
      refute code1 == code2
    end
  end
end
