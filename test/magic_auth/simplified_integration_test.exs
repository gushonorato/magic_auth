defmodule MagicAuth.SimplifiedIntegrationTest do
  use ExUnit.Case, async: false
  
  alias MagicAuth.{Config, ExampleConfigPlug}

  describe "simplified per-request configuration" do
    test "full flow: plug sets config, on_mount restores it" do
      # Step 1: Clear any existing config
      Process.delete(:magic_auth_config)
      
      # Step 2: Simulate HTTP request with config plug
      ExampleConfigPlug.call(%Plug.Conn{}, [])
      
      # Verify config is set for HTTP request
      assert Config.one_time_password_length() == 6
      assert Config.remember_me() == true
      
      # Step 3: Clear config to simulate LiveView process spawn
      Process.delete(:magic_auth_config)
      
      # Verify config is gone
      Application.put_env(:magic_auth, :one_time_password_length, 99)
      assert Config.one_time_password_length() == 99  # Falls back to Application
      
      # Step 4: Simulate LiveView mount with on_mount callback
      socket = %Phoenix.LiveView.Socket{}
      {:cont, _socket} = ExampleConfigPlug.on_mount(:set_magic_auth_config, %{}, %{}, socket)
      
      # Verify config is restored for LiveView
      assert Config.one_time_password_length() == 6
      assert Config.remember_me() == true
      
      # Clean up
      Application.delete_env(:magic_auth, :one_time_password_length)
    end
    
    test "multiple config plugs can coexist" do
      # Create a second config plug
      defmodule TestConfigPlug do
        def set_different_config do
          config = %{
            one_time_password_length: 8,
            remember_me: false
          }
          Process.put(:magic_auth_config, config)
        end
        
        def on_mount(:set_different_config, _params, _session, socket) do
          set_different_config()
          {:cont, socket}
        end
      end
      
      # Test first config
      Process.delete(:magic_auth_config)
      ExampleConfigPlug.call(%Plug.Conn{}, [])
      assert Config.one_time_password_length() == 6
      
      # Test second config
      Process.delete(:magic_auth_config)
      TestConfigPlug.set_different_config()
      assert Config.one_time_password_length() == 8
      assert Config.remember_me() == false
      
      # Test on_mount callbacks
      Process.delete(:magic_auth_config)
      socket = %Phoenix.LiveView.Socket{}
      {:cont, _socket} = TestConfigPlug.on_mount(:set_different_config, %{}, %{}, socket)
      assert Config.one_time_password_length() == 8
    end
  end
end