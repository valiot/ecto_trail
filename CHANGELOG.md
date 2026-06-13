# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-06-13

### Fixed

- `update_and_log/4` (and sibling `*_and_log`) no longer raise raw `Ecto.ConstraintError` on `audit_logs_pkey` (or equivalent table pkey) under concurrent updates or sequence skew. Include `:id` in cast and declare `unique_constraint(:id)` so collisions become graceful changeset errors. Added regression test that forces pkey collision. Closes OPS-4628.
- README and moduledoc migration examples now include `change_type` column (was missing from docs but present in real migration).

## [1.0.3] - 2026-05-28

### Fixed

- `*_and_log/*` and `log/*` no longer raise a `:rollback` `RuntimeError` when called from inside an `Ecto.Multi`. Closes OPS-3479.

## [1.0.2] - 2025-04-07

### Changed

- Refactor for performance and idiomatic Elixir (see git history).

## [Unreleased / prior]

See git log for earlier history (original author Nebo15 / Valiot).
