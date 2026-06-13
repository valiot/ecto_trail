# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-06-13

### Fixed

- `log_changes/5` (called by `update_and_log/4`, `insert_and_log/4`, etc.) now declares `unique_constraint(:id, name: <audit_log_pkey>)` on the internal audit log changeset. This converts a duplicate pkey violation (e.g. "audit_logs_pkey") into a regular `{:error, changeset}` instead of raising `Ecto.ConstraintError`. The pkey name defaults to `#{table_name}_pkey` (table_name defaults to "audit_log"). Closes OPS-4596.

## [1.0.3] - 2026-05-28

### Fixed

- `*_and_log/*` and `log/*` no longer raise a `:rollback` `RuntimeError` when called from inside an `Ecto.Multi`. Closes OPS-3479.

## [1.0.2] - 2025-04-07

### Changed

- Refactor for performance and idiomatic Elixir (see git history).

## [Unreleased / prior]

See git log for earlier history (original author Nebo15 / Valiot).
