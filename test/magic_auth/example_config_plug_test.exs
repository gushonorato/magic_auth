defmodule MagicAuth.ExampleConfigPlugTest do
  use ExUnit.Case, async: false
  
  alias MagicAuth.{Config, ExampleConfigPlug}

  describe "simplified config plug" do
    test "sets config values correctly" do
      # Clear any existing process config
      Process.delete(:magic_auth_config)
      
      # Call the simplified plug
      ExampleConfigPlug.call(%Plug.Conn{}, [])
      
      # Verify ProcessTree config is set
      assert Config.one_time_password_length() == 6
      assert Config.one_time_password_expiration() == 5
      assert Config.remember_me() == true
      assert Config.rate_limit_enabled?() == true
    end
    
    test "on_mount callback sets config correctly" do
      # Clear any existing process config
      Process.delete(:magic_auth_config)
      
      # Call the on_mount callback
      socket = %Phoenix.LiveView.Socket{}
      {:cont, _socket} = ExampleConfigPlug.on_mount(:set_magic_auth_config, %{}, %{}, socket)
      
      # Verify config was set
      assert Config.one_time_password_length() == 6
      assert Config.one_time_password_expiration() == 5
      assert Config.remember_me() == true
      assert Config.rate_limit_enabled?() == true
    end
    
    test "fallback to Application config when no process config" do
      # Clear any process config
      Process.delete(:magic_auth_config)
      
      # Set Application config
      Application.put_env(:magic_auth, :one_time_password_length, 7)
      
      try do
        # Should use Application config when no ProcessTree config exists
        assert Config.one_time_password_length() == 7
      after
        Application.delete_env(:magic_auth, :one_time_password_length)
      end
    end
  end
end