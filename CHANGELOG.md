# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-06-13

### Fixed

- Declare `unique_constraint/3` for the audit log pkey (`<table>_pkey`) in `changelog_changeset`. Prevents Ecto.ConstraintError on `audit_logs_pkey` (or equivalent) during `EctoTrail.update_and_log` (and siblings) when the sequence produces a colliding id. The constraint violation is mapped to a changeset error and handled gracefully by the existing logging error path. Closes OPS-4595.

## [1.0.3] - 2026-05-28

### Fixed

- `*_and_log/*` and `log/*` no longer raise a `:rollback` `RuntimeError` when called from inside an `Ecto.Multi`. Closes OPS-3479.

## [1.0.2] - 2025-04-07

### Changed

- Refactor for performance and idiomatic Elixir (see git history).

## [Unreleased / prior]

See git log for earlier history (original author Nebo15 / Valiot).
