defmodule MagicAuth.TokenTest do
  use MagicAuth.DataCase, async: true
  alias MagicAuth.Token

  describe "changeset/2" do
    test "creates a valid changeset with correct attributes" do
      attrs = %{email: "usuario@exemplo.com", value: "123456"}
      changeset = Token.changeset(%Token{}, attrs)
      assert changeset.valid?
    end

    test "returns error when email is missing" do
      attrs = %{value: "123456"}
      changeset = Token.changeset(%Token{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).email
    end

    test "returns error when value is missing" do
      attrs = %{email: "usuario@exemplo.com"}
      changeset = Token.changeset(%Token{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).value
    end

    test "returns error for invalid email format" do
      attrs = %{email: "email_invalido", value: "123456"}
      changeset = Token.changeset(%Token{}, attrs)
      refute changeset.valid?
      assert "has invalid format" in errors_on(changeset).email
    end
  end
end
