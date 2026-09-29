defmodule MagicAuth.PasswordLiveTest do
  use ExUnit.Case, async: false

  import Mox
  import MagicAuthTest.Helpers

  alias MagicAuth.PasswordLive
  alias Phoenix.LiveView.Socket

  setup :verify_on_exit!
  setup :preserve_app_env

  describe "mount/3" do
    test "assigns the page title returned by the callback" do
      expect(MagicAuthTestWeb.CallbacksMock, :page_title, fn :password -> "Enter verification code" end)

      {:ok, socket} = PasswordLive.mount(%{}, %{}, %Socket{})

      assert socket.assigns.page_title == "Enter verification code"
    end

    test "doesn't assign the page title when the callback isn't implemented" do
      Application.put_env(:magic_auth, :callbacks, MagicAuthTestWeb.CallbacksWithoutOptionalMock)

      {:ok, socket} = PasswordLive.mount(%{}, %{}, %Socket{})

      refute Map.has_key?(socket.assigns, :page_title)
    end
  end
end
