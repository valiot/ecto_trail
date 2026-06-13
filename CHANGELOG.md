# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-06-13

### Fixed

- `Changelog` schema now declares `@primary_key {:id, :binary_id, autogenerate: true}` so `*_and_log` and `log` always insert with a generated UUIDv4 (prevents serial/id collisions that surface as `Ecto.ConstraintError` on `audit_logs_pkey`). `changelog_changeset/1` now registers `unique_constraint(:id)` so violations become changeset errors instead of raised constraint exceptions. Closes OPS-4607.

## [1.0.3] - 2026-05-28

### Fixed

- `*_and_log/*` and `log/*` no longer raise a `:rollback` `RuntimeError` when called from inside an `Ecto.Multi`. Closes OPS-3479.

## [1.0.2] - 2025-04-07

### Changed

- Refactor for performance and idiomatic Elixir (see git history).

## [Unreleased / prior]

See git log for earlier history (original author Nebo15 / Valiot).
