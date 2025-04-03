# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0]

### Enhancements

  - Making the messages more visible when the task `mix magic_auth.install` fails to inject code into the files
  - If a tuple `{:allow, user_id}` is returned from the `log_in_requested/1` callback, Magic Auth will store the user `ID` in 
    `%Session{user_id: user_id}`. The user will then be automatically loaded by `fetch_magic_auth_session/2` and assigned 
    to `assigns` under the `:current_user` key.
  - Support for multi tenancy with query prefixes and foreign keys.
  - Add default logging of success and error messages in generated email-sending code

### Breaking changes
  - Removed `MagicAuth.delete_all_sessions_by_token/1`. Use `MagicAuth.log_out/1` instead.
  - Removed `MagicAuth.delete_all_sessions_by_email/1`. Use `MagicAuth.log_out_all/1` instead.
  - Magic Auth now redirects to the configured log in page instead of `/` after log out.

### How use automatic user loading feature on legacy project

  To support the automatic user loading feature, a few small changes must be made to your project before updating (only if you want to use this functionality):

  1. Add `user_id` column on `magic_auth_sessions` table.
  ```elixir
  alter table(:magic_auth_sessions) do
    add :user_id, :integer, null: true
  end
  ```

  2. Add your user schema to the Magic Auth configuration on `config/config.exs`:
  ```elixir
  config :magic_auth,
    get_user: %MyApp.Accounts.get_user_by_id/1
  ```

  DONE!

## [0.1.1] - 2025-01-29

### Fixed

  - One-time passwords are not being deleted after verified, allowing them to be reused multiple times until they expire.

## [0.1.0] - 2025-01-22

This is the first release of `magic_auth`.

### Added
- Installation generator `mix magic_auth.install`
- Email-based one-time password authentication
- Customizable login and verification forms
- Customizable email templates
- Configurable access control logic
- Customizable error message translations
- Complete documentation with examples
- Support for standard and umbrella Phoenix projects
- Swoosh integration for email delivery
- Comprehensive automated test suite

