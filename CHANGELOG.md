# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-06-13

### Fixed

- Add `unique_constraint/3` for audit log PK (covers `audit_log_pkey`, `audit_logs_pkey`, and dynamic table name) in `changelog_changeset` so `*_and_log/*` and `log/*` turn `Ecto.ConstraintError` on pkey collisions into changeset errors (instead of raising). Matches observed prod error during `upsert_and_log`. Closes OPS-4568.

## [1.0.3] - 2026-05-28

### Fixed

- `*_and_log/*` and `log/*` no longer raise a `:rollback` `RuntimeError` when called from inside an `Ecto.Multi`. Closes OPS-3479.

## [1.0.2] - 2025-04-07

### Changed

- Refactor for performance and idiomatic Elixir (see git history).

## [Unreleased / prior]

See git log for earlier history (original author Nebo15 / Valiot).
