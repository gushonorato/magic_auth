# 🔒 Magic Auth &nbsp;  &nbsp;  &nbsp; &nbsp;  ![CI](https://github.com/gushonorato/magic_auth/workflows/CI/badge.svg) [![](https://img.shields.io/badge/documentation-indigo)](https://hexdocs.pm/magic_auth)

Magic Auth is an authentication library for Phoenix that provides effortless configuration and flexibility for your project.

![Magic Auth in action](https://github.com/user-attachments/assets/b9ccbb5d-4f42-48c6-9847-af51fec5b155)

## Key Features

- **Ship Faster** 🚀: No time wasted configuring password resets and recovery flows - just implement and ship your product.
- **Passwordless Authentication** 📨: Secure login process through one-time passwords sent via email. One-time passwords are better than magic links because users can receive the code on one device (e.g., phone email) and enter it on another (e.g., desktop browser).
- **Enhanced Security** 🔒: Protect your application from brute force attacks with built-in rate limiting and account lockout mechanisms.
- **Customizable Interface 🎨:** Use the beautiful default UI components out of the box, or customize them fully to match your design perfectly.
- **Effortless Configuration and Comprehensive Documentation** 📚: Quick and simple integration with your Phoenix project, with detailed guides and references to assist you through every step of the integration process.
- **Schema Agnostic** 👤: Implement authentication without requiring a user schema - ideal for everything from MVPs to complex applications.

## Documentation

You can find the full documentation for Magic Auth on [HexDocs](https://hexdocs.pm/magic_auth).

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

## Support This Project

If you find Magic Auth helpful, show your support by:
- Starring ⭐ the project on GitHub
- Following me on X (formerly Twitter): @gushonorato

## Acknowledgements

Much of the code in this library is based on the `mix phx.gen.auth` generator. Special thanks to all the contributors of `mix phx.gen.auth` for their hard work and dedication in creating such a valuable tool for the Phoenix community. Your efforts have significantly inspired and influenced the development of Magic Auth.

## Copyright and License
Copyright (c) 2025, Gustavo Honorato.

Magic Auth source code is licensed under the MIT License.
