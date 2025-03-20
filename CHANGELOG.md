# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0]

  - Making the messages more visible when the task `mix magic_auth.install` fails to inject code into the files

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

