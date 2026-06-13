# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-06-13

### Fixed

- `*_and_log/*` (and `log/*`) no longer raise `Ecto.ConstraintError` on `audit_log_pkey` (unique_constraint) when the audit log insert inside the transaction collides on the primary key. The `unique_constraint` is now declared so the error is handled gracefully (audit failures remain non-fatal to the user operation per existing contract). Closes OPS-4570.

## [1.0.3] - 2026-05-28

### Fixed

- `*_and_log/*` and `log/*` no longer raise a `:rollback` `RuntimeError` when called from inside an `Ecto.Multi`. Closes OPS-3479.

## [1.0.2] - 2025-04-07

### Changed

- Refactor for performance and idiomatic Elixir (see git history).

## [Unreleased / prior]

See git log for earlier history (original author Nebo15 / Valiot).
