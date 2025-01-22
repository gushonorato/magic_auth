# Magic Auth
Magic Auth is an authentication library for Phoenix that provides effortless configuration and flexibility for your project.

![Magic Auth in action](https://github.com/user-attachments/assets/b9ccbb5d-4f42-48c6-9847-af51fec5b155)

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
    # Use MagicAuth.require_authenticated/2 plug to protect controllers
    pipe_through [:browser, :require_authenticated]

    get "/protected_controller", ProtectedController, :index

    # Use MagicAuth.required_authenticated/4 to protect LiveViews
    live_session :authenticated, on_mount: [{MagicAuth, :require_authenticated}] do
      live "/protected_live_view", ProtectedLiveView
    end
  end
end
```

For more details, refer to `MagicAuth.require_authenticated/2` and `MagicAuth.on_mount/4`.

## Customization
The generator will create a file at `lib/my_app_web/magic_auth.ex` (or at `apps/my_app_web/lib/my_app_web/magic_auth.ex` in an umbrella project). It contains several callbacks that you can modify to match your application's needs. Below is a brief explanation of each callback:

- Customize the log in form appearance by modifying `log_in_form/1`.
- Customize the verification form appearance by modifying `verify_form/1`.
- Customize email templates by modifying `one_time_password_requested/1`, `text_email_body/1`, and `html_email_body/1`.
- Customize access control logic by modifying `log_in_requested/1`.
- Customize error message translations by modifying `translate_error/1`.

This file is filled with comprehensive comments that guide you through customizing both the appearance and behavior of Magic Auth. For detailed instructions, please refer to the comments in the generated file.

## Contributing

We welcome contributions! Here's how you can help improve Magic Auth:

### Development Setup

Clone the repository
```bash
git clone https://github.com/your-username/magic_auth.git
cd magic_auth
```

Install dependencies
```bash
mix deps.get
```

Setup the test database
```bash
mix magic_auth.setup_test_db
```

### Running Tests

Execute the test suite with:
```bash
mix test
```

Alternatively, you can use `mix test.watch` for automatic test execution on file changes:

```bash
mix test.watch
```

### Building Documentation

Generate documentation locally:
```bash
mix docs
```

### Compilation

Compile the project:
```bash
mix compile
```

Before submitting a pull request, please:
- Ensure all tests pass
- Add tests for new functionality
- Update documentation as needed
- Follow the existing code style

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/magic_auth>.

## Acknowledgements

Much of the code in this library is based on the `mix phx.gen.auth` generator. Special thanks to all the contributors of `mix phx.gen.auth` for their hard work and dedication in creating such a valuable tool for the Phoenix community. Your efforts have significantly inspired and influenced the development of Magic Auth.

## Copyright and License
Copyright (c) 2025, Gustavo Honorato.

Magic Auth source code is licensed under the MIT License.
