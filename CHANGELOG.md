# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-06-13

### Fixed

- `changelog_changeset/1` now includes `:id` and declares `unique_constraint(:id, name: "#{table}_pkey")`. This prevents `Ecto.ConstraintError` on the audit log primary key (e.g. `audit_logs_pkey`) when `update_and_log` / `insert_and_log` etc. run inside a transaction and the id sequence produces a duplicate (sequence skew, explicit reuse, or concurrent writers). Added TDD regression test for the pkey collision path. Upgraded within-range dev deps (benchee, credo). Closes OPS-4626.

## [1.0.3] - 2026-05-28

### Fixed

- `*_and_log/*` and `log/*` no longer raise a `:rollback` `RuntimeError` when called from inside an `Ecto.Multi`. Closes OPS-3479.

## [1.0.2] - 2025-04-07

### Changed

- Refactor for performance and idiomatic Elixir (see git history).

## [Unreleased / prior]

See git log for earlier history (original author Nebo15 / Valiot).
