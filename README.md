# MagicAuth

MagicAuth is an authentication library for Phoenix that provides effortless configuration and flexibility for your project.

## Key Features

- **Schema Agnostic**: Implement authentication without even having a user schema - perfect for MVPs or simple applications
- **Ship Faster**: No time wasted configuring password resets and recovery flows - just implement and ship your product
- **Effortless Configuration**: Quick and simple integration with your Phoenix project
- **Customizable Interface**: Fully customizable UI components to match your design
- **Passwordless Authentication**: Secure login process through magic links and one-time passwords sent via email

## Installation

To install MagicAuth, add it to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:magic_auth, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/magic_auth>.