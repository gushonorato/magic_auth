# 🔒 Magic Auth

Magic Auth is an authentication library for Phoenix that provides effortless configuration and flexibility for your project.

![Magic Auth in action](assets/magic_auth_in_action.gif)

## Key Features

- **Ship Faster** 🚀: No time wasted configuring password resets and recovery flows - just implement and ship your product.
- **Passwordless Authentication** 📨: Secure login process through one-time passwords sent via email. One-time passwords are better than magic links because users can receive the code on one device (e.g., phone email) and enter it on another (e.g., desktop browser).
- **Enhanced Security** 🔒: Protect your application from brute force attacks with built-in rate limiting and account lockout mechanisms.
- **Customizable Interface** 🎨: Fully customizable UI components to match your design.
- **Effortless Configuration and Comprehensive Documentation** 📚: Quick and simple integration with your Phoenix project, with detailed guides and references to assist you through every step of the integration process.
- **Schema Agnostic** 👤: Implement authentication without requiring a user schema - ideal for everything from MVPs to complex applications.

## Installation

To install Magic Auth, add it to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:magic_auth, "~> 0.1.0"}
  ]
end
```

## Getting started

Magic Auth simplifies the process of adding authentication to your Phoenix application. You'll have a fully functional authentication system integrated into your Phoenix application in less than 5 minutes. It's just 2 easy and quick steps!

### Step 1 - Run generator

After adding Magic Auth to your dependencies, you can quickly set up authentication in your Phoenix application using the installation generator:

```bash
mix magic_auth.install
```

If you are working within an umbrella project, navigate to your web application directory and run the generator:

```bash
cd apps/my_app_web/ && mix magic_auth.install
```

Don't forget to run the migrations to create the necessary tables for Magic Auth:

```bash
mix ecto.migrate
```

### Step 2 - Protect your routes

To protect your controllers and LiveViews with authentication, you need to configure the appropriate plugs and LiveView mounts. Edit the `lib/my_app_web/router.ex` file and modify it as shown in the example below:

```elixir
defmodule MyAppWeb.Router do 
  # Additional router contents...

  scope "/", MyAppWeb do
    # Add MagicAuth.require_authenticated/2 plug to protect controllers
    # and LiveView first mount (disconnected)
    pipe_through [:browser, :require_authenticated]

    get "/protected_controller", ProtectedController, :index

    # Use MagicAuth.required_authenticated/4 to protect LiveView's socket connection
    live_session :authenticated, on_mount: [{MagicAuth, :require_authenticated}] do
      live "/protected_live_view", ProtectedLiveView
    end
  end
end
```

For more details, refer to `MagicAuth.require_authenticated/2` and `MagicAuth.on_mount/4`.

## Creating a log out link

After setting up authentication, you must provide users with a way to log out. Magic Auth provides helper functions to generate the correct path for this action:

```elixir
<.link method="delete" href={~p"/sessions/log_out"}>Logout</.link>
```

## Logging out from all sessions

Magic Auth allows users to log out from all active sessions across all devices. This is useful for security purposes when a user suspects unauthorized access to their account.

To create a link that logs out from all sessions, use the following code:

```elixir
<.link method="delete" href={~p"/sessions/log_out/all"}>Logout</.link>
```

## Logging out from a LiveView

Since it's not possible to redirect to a route that accepts the DELETE method, Magic Auth alternatively creates a route to log out from all sessions using a GET method so it can be used within a LiveView event. For all other cases, you must use the DELETE method for logging out of sessions. Using the GET method to remove sessions indiscriminately, such as in `<.links>`, can cause incorrect behavior of your web application.

```elixir
def handle_event("save", _params, socket) do 
  {:noreply, redirect(socket, to: ~p"/sessions/log_out/all/get")}
end
```

If you want to log out from all sessions

See all generated routes in [Introspection Functions](/magic_auth/MagicAuth.Router.html#module-introspection-functions) section of the `MagicAuth.Router` documentation.

## Customization
The generator will create a file at `lib/my_app_web/magic_auth.ex` (or at `apps/my_app_web/lib/my_app_web/magic_auth.ex` in an umbrella project). This file contains several callbacks that you can modify to match your application's needs. It is filled with comprehensive comments that guide you through customizing both the appearance and behavior of Magic Auth. For detailed instructions, please refer to the comments in the generated file. Below is a brief explanation of what can be customized:

- The log in form appearance by modifying `log_in_form/1`.
- The verification form appearance by modifying `verify_form/1`.
- E-mail templates by modifying `one_time_password_requested/1`, `text_email_body/1`, and `html_email_body/1`.
- Access control logic by modifying `log_in_requested/1`.
- Error message translations by modifying `translate_error/1`.

## Multi-tenant applications

Magic Auth supports the two most common types of multi-tenant applications: those using [query prefixes](https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html) and those using [foreign keys](https://hexdocs.pm/ecto/multi-tenancy-with-foreign-keys.html). 

### Multi-tenancy with Foreign Keys

Assuming you followed the Ecto guide on multi-tenancy, your repo should look like this:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app

  require Ecto.Query

  @impl true
  def prepare_query(_operation, query, opts) do
    cond do
      opts[:skip_org_id] || opts[:ecto_query] in [:schema_migration, :preload] ->
        {query, opts}

      org_id = opts[:org_id] ->
        {Ecto.Query.where(query, org_id: ^org_id), opts}

      true ->
        raise "expected org_id or skip_org_id to be set"
    end
  end
end
```

You can modify the first condition of your `cond` clause to include `opts[:magic_auth]` like this:

```elixir
opts[:magic_auth] || opts[:skip_org_id] || opts[:ecto_query] in [:schema_migration, :preload] ->
  {query, opts}
end
```

Alternatively, if you prefer not to modify your `Repo`, you can configure Magic Auth to pass `skip_org_id: true` in
all queries using the `:repo_opts` configuration:

```elixir
# config/config.ex

config :magic_auth,
  repo_opts: [skip_org_id: true]
```

### Multi-tenancy with Query prefixes

You can dynamically set the database prefix by passing a function to the `:repo_opts` configuration:

```elixir
# config/config.exs
config :magic_auth,
  repo_opts: fn ->
    [prefix: Process.get({MyApp.Repo, :org_id})]
  end
```