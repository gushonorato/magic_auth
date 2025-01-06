defmodule MagicAuth.RouterTest.TestRouter do
  use Phoenix.Router, helpers: false
  use MagicAuth.Router

  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  magic_auth()
end
