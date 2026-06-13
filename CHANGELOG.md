# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-06-13

### Fixed

- `*_and_log/*` and `log_changes` now declare `unique_constraint/3` for common audit table pkey names (`audit_log_pkey`, `audit_logs_pkey`, `${table}_pkey`). Prevents Ecto.ConstraintError on pkey collision (e.g. sequence rewind or concurrent upserts) and lets the existing error-swallowing path handle it gracefully. Closes OPS-4567.

### Changed

- Upgraded benchee (1.5.0→1.5.1) and credo (1.7.18→1.7.19) within allowed ranges (deps freshness).

## [1.0.3] - 2026-05-28

### Fixed

- `*_and_log/*` and `log/*` no longer raise a `:rollback` `RuntimeError` when called from inside an `Ecto.Multi`. Closes OPS-3479.

## [1.0.2] - 2025-04-07

### Changed

- Refactor for performance and idiomatic Elixir (see git history).

## [Unreleased / prior]

See git log for earlier history (original author Nebo15 / Valiot).
