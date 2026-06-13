# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-06-13

### Fixed

- `changelog_changeset` now casts `:id` and declares `unique_constraint(:id, name: "#{table}_pkey")`. Raw `Ecto.ConstraintError` on `audit_log(s)_pkey` during `*_and_log` (e.g. `update_and_log` inside a transaction) becomes a regular `{:error, changeset}` instead of bubbling out. Closes OPS-4563.

## [1.0.3] - 2026-05-28

### Fixed

- `*_and_log/*` and `log/*` no longer raise a `:rollback` `RuntimeError` when called from inside an `Ecto.Multi`. Closes OPS-3479.

## [1.0.2] - 2025-04-07

### Changed

- Refactor for performance and idiomatic Elixir (see git history).

## [Unreleased / prior]

See git log for earlier history (original author Nebo15 / Valiot).
