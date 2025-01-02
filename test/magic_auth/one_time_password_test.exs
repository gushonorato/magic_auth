defmodule MagicAuth.OneTimePasswordTest do
  use MagicAuth.DataCase, async: true
  alias MagicAuth.OneTimePassword

  describe "changeset/2" do
    test "creates a valid changeset with correct attributes" do
      attrs = %{email: "usuario@exemplo.com"}
      changeset = OneTimePassword.changeset(%OneTimePassword{}, attrs)
      assert changeset.valid?
    end

    test "returns error when email is missing" do
      attrs = %{}
      changeset = OneTimePassword.changeset(%OneTimePassword{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).email
    end

    test "returns error for invalid email format" do
      attrs = %{email: "invalid_mail"}
      changeset = OneTimePassword.changeset(%OneTimePassword{}, attrs)
      refute changeset.valid?
      assert "has invalid format" in errors_on(changeset).email
    end
  end
end
