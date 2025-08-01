defmodule MagicAuth.ExampleConfigPlug do
  @moduledoc """
  Example plug demonstrating how to configure MagicAuth per-request.
  
  This plug sets process-local configuration that will be used by MagicAuth
  instead of the global Application configuration.
  
  ## Usage
  
  In your router:
  
      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_live_flash
        plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
        plug :protect_from_forgery
        plug :put_secure_browser_headers
        plug MagicAuth.ExampleConfigPlug
        plug :fetch_magic_auth_session
      end

      magic_auth("/auth",
        on_mount: [
          {MagicAuth.ExampleConfigPlug, :set_magic_auth_config},
          {MagicAuth, :redirect_if_authenticated}
        ]
      )
  """
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    set_magic_auth_config()
    conn
  end
  
  def set_magic_auth_config do
    config = %{
      one_time_password_length: 6,
      one_time_password_expiration: 5,
      remember_me: true,
      enable_rate_limit: true
    }
    
    Process.put(:magic_auth_config, config)
  end
  
  def on_mount(:set_magic_auth_config, _params, _session, socket) do
    set_magic_auth_config()
    {:cont, socket}
  end
end