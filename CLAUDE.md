# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Magic Auth is an Elixir Phoenix authentication library that provides passwordless authentication using one-time passwords sent via email. It's designed for effortless setup with built-in rate limiting, security features, and customizable UI components.

## Development Commands

### Testing
- Run all tests: `mix test`
- Run tests with file watching: `mix test.watch`
- Set up test database: `mix magic_auth.setup_test_db`

### Building and Documentation
- Compile the project: `mix compile`
- Generate documentation: `mix docs`
- Install dependencies: `mix deps.get`

### Important Test Configuration
When running tests, rate limiting should be disabled in test environment:
```elixir
# config/test.exs
config :magic_auth,
  enable_rate_limit: false
```

## Architecture Overview

### Core Authentication Flow
1. **One-Time Password Generation** (`MagicAuth.create_one_time_password/1`)
   - Creates and sends OTP via configured callback
   - Rate limited to 1 request per minute per email
   - OTP expires after 10 minutes by default

2. **Authentication** (`MagicAuth.log_in/3`)
   - Verifies OTP and creates session
   - Rate limited to 10 attempts per 10 minutes per email
   - Supports access control via callback responses

3. **Session Management** (`MagicAuth.Session`)
   - Token-based sessions with configurable validity (60 days default)
   - Remember me functionality via signed cookies
   - Support for multi-session management

### Key Modules

**Core Library (`lib/magic_auth.ex`)**
- Main authentication functions
- Session management and plugs
- Rate limiting integration

**Configuration (`lib/magic_auth/config.ex`)**
- Centralized configuration management
- Required configs: `:repo`, `:router`, `:callbacks`, `:endpoint`, `:remember_me_cookie`
- Optional configs for customization

**LiveView Components**
- `LoginLive`: Email entry page
- `PasswordLive`: OTP entry page
- Both use redirect-if-authenticated mount hook

**Token Buckets (`lib/magic_auth/token_buckets/`)**
- `OneTimePasswordRequestTokenBucket`: Rate limits OTP requests
- `LoginAttemptTokenBucket`: Rate limits login attempts
- Both supervised processes for rate limiting

**Router Integration (`lib/magic_auth/router.ex`)**
- Provides `magic_auth/2` macro for route configuration
- Generates authentication routes with customizable paths
- Built-in pipeline integration

### Database Schema
- `MagicAuth.OneTimePassword`: Stores hashed OTPs with email and expiration
- `MagicAuth.Session`: Stores session tokens with user association

### Multi-tenancy Support
- Repository operations support dynamic options via `repo_opts` config
- Can be function returning tenant-specific options (e.g., prefix)

### Security Features
- Bcrypt for password hashing
- Timing attack protection
- CSRF token management
- Session fixation attack prevention
- Built-in rate limiting with token bucket algorithm

## Testing Patterns

Use `MagicAuth.TestHelpers.log_in_session/2` for testing authenticated routes:

```elixir
defmodule MyApp.MyModuleTest do
  use MyApp.ConnCase, async: true
  import MagicAuth.TestHelpers

  test "authenticated route", %{conn: conn} do
    conn = log_in_session(conn, %{email: "test@example.com"})
    # Test assertions
  end
end
```

## Configuration Requirements

Applications using Magic Auth must configure:
- Repository module
- Router module  
- Callback module implementing required functions
- Phoenix endpoint
- Remember me cookie name
- Optional: user retrieval function for `current_user` assigns