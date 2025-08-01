# Per-Request Configuration

Magic Auth supports per-request configuration, allowing you to use different authentication settings for different parts of your application. This is useful for multi-tenant applications, applications with different user types, or applications that serve multiple hosts with varying authentication requirements.

## How It Works

Magic Auth uses the ProcessTree library to provide process-local configuration that appears global to the current request and its child processes (including LiveView processes). When a configuration map is stored in the process dictionary with the key `:magic_auth_config`, Magic Auth will use those values instead of the global Application configuration.

## Basic Usage

### Step 1: Create a Configuration Plug

Create a plug that sets the configuration for your application:

```elixir
defmodule MyApp.MagicAuthConfigPlug do
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
      enable_rate_limit: true,
      router: MyAppWeb.Router  # Important for multi-router setups
    }
    
    Process.put(:magic_auth_config, config)
  end
  
  def on_mount(:set_magic_auth_config, _params, _session, socket) do
    set_magic_auth_config()
    {:cont, socket}
  end
end
```

### Step 2: Configure Your Router

Add the configuration plug to your browser pipeline and configure Magic Auth with the on_mount callback:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  use MagicAuth.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug MyApp.MagicAuthConfigPlug  # Add your config plug here
    plug :fetch_magic_auth_session
  end

  magic_auth("/auth",
    log_in: "/login",
    password: "/password", 
    log_out: "/logout",
    on_mount: [
      {MyApp.MagicAuthConfigPlug, :set_magic_auth_config},  # Restore config for LiveView
      {MagicAuth, :redirect_if_authenticated}               # Handle authentication
    ]
  )

  scope "/", MyAppWeb do
    pipe_through :browser
    
    get "/", PageController, :home
    live "/dashboard", DashboardLive
  end
end
```

## Configuration Options

The `magic_auth` macro accepts the following configuration options:

- `:authenticated_pipeline` - Pipeline for authenticated routes (logout routes). Default: `[:browser, :require_authenticated]`
- `:unauthenticated_pipeline` - Pipeline for unauthenticated routes (login, password, verify). Default: `[:browser, :redirect_if_authenticated]`
- `:on_mount` - List of on_mount tuples for LiveView. Default: `[{MagicAuth, :redirect_if_authenticated}]`

This allows you to include your configuration plugs in the authentication flow and ensure LiveView processes get the correct configuration.

## Available Configuration Values

You can override any of the following configuration values on a per-request basis:

- `:repo` - The Ecto repository module
- `:router` - Your application's router module
- `:callbacks` - Module implementing MagicAuth callback functions
- `:endpoint` - Your Phoenix application's endpoint module
- `:remember_me_cookie` - Name of the remember me cookie
- `:get_user` - Function to retrieve user by ID
- `:repo_opts` - Options passed to repository calls
- `:one_time_password_length` - Length of generated codes
- `:one_time_password_expiration` - Expiration time in minutes
- `:remember_me` - Whether to enable remember me functionality
- `:session_validity_in_days` - How long sessions remain valid
- `:enable_rate_limit` - Whether to enable rate limiting

## Advanced Configuration

### Multi-Host Configuration

For applications with multiple hosts, create separate config plugs for each:

```elixir
defmodule MyApp.AdminMagicAuthPlug do
  def init(opts), do: opts
  
  def call(conn, _opts) do
    set_magic_auth_config()
    conn
  end
  
  def set_magic_auth_config do
    config = %{
      callbacks: MyApp.AdminMagicAuthCallbacks,
      router: MyAppWeb.AdminRouter,
      one_time_password_length: 8,
      remember_me: false
    }
    
    Process.put(:magic_auth_config, config)
  end
  
  def on_mount(:set_magic_auth_config, _params, _session, socket) do
    set_magic_auth_config()
    {:cont, socket}
  end
end

defmodule MyApp.CustomerMagicAuthPlug do
  def init(opts), do: opts
  
  def call(conn, _opts) do
    set_magic_auth_config()
    conn
  end
  
  def set_magic_auth_config do
    config = %{
      callbacks: MyApp.CustomerMagicAuthCallbacks,
      router: MyAppWeb.CustomerRouter,
      one_time_password_length: 6,
      remember_me: true
    }
    
    Process.put(:magic_auth_config, config)
  end
  
  def on_mount(:set_magic_auth_config, _params, _session, socket) do
    set_magic_auth_config()
    {:cont, socket}
  end
end
```

Then use different plugs in different routers:

```elixir
# AdminRouter
pipeline :browser do
  plug MyApp.AdminMagicAuthPlug
  # ... other plugs
end

# CustomerRouter  
pipeline :browser do
  plug MyApp.CustomerMagicAuthPlug
  # ... other plugs
end
```

### Dynamic Configuration

You can also build configurations dynamically based on request parameters, session data, or database lookups:

```elixir
defmodule MyApp.TenantMagicAuthPlug do
  def init(opts), do: opts
  
  def call(conn, _opts) do
    tenant = get_tenant_from_subdomain(conn.host)
    
    config = %{
      callbacks: Module.concat([MyApp, tenant.name, MagicAuthCallbacks]),
      remember_me_cookie: "#{tenant.slug}_magic_auth_remember_me",
      one_time_password_length: tenant.security_settings.otp_length,
      one_time_password_expiration: tenant.security_settings.otp_expiration
    }
    
    Process.put(:magic_auth_config, config)
    conn
  end
  
  defp get_tenant_from_subdomain(host) do
    # Your tenant lookup logic here
  end
end
```

## LiveView Compatibility

LiveView processes run in separate processes and don't automatically inherit ProcessTree configuration. To solve this, you need to provide custom `on_mount` callbacks that restore the configuration.

### How it works:

1. **Configuration plugs** store config in both ProcessTree (for HTTP requests) and the session (for LiveView access)
2. **Custom on_mount callbacks** restore the config from the session to the LiveView process
3. **Magic Auth's on_mount callbacks** handle authentication after config is restored

### The on_mount Chain:

```elixir
magic_auth("/sessions",
  on_mount: [
    {MyApp.ConfigPlug, :restore_config},        # First: restore config
    {MagicAuth, :redirect_if_authenticated}     # Then: handle authentication
  ]
)
```

This ensures that:
1. Configuration is restored before any Magic Auth functions are called
2. LiveView processes have access to the same configuration as their parent HTTP request
3. Authentication logic works correctly with the restored configuration

## Fallback Behavior

If no per-request configuration is set, Magic Auth automatically falls back to the global Application configuration. This ensures backward compatibility with existing applications.

## Testing

When testing with per-request configuration, you can set the configuration directly in your tests:

```elixir
test "admin authentication with custom config" do
  config = %{
    one_time_password_length: 8,
    remember_me: false
  }
  
  Process.put(:magic_auth_config, config)
  
  # Your test code here
end
```

## Migration Guide

Existing applications will continue to work without any changes. To add per-request configuration:

1. Create configuration plugs for your different contexts
2. Add the plugs to your router pipelines before `:fetch_magic_auth_session`
3. Test that your configuration overrides work as expected

The per-request configuration only overrides the values you specify. Any values not included in the configuration map will fall back to the Application configuration.