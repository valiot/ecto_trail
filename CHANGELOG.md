# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-06-13

### Fixed

- `update_and_log/4` (and other `*_and_log`) no longer raise `Ecto.ConstraintError` on `audit_log(s)_pkey` when the audit log insert hits a primary key collision; the error is now coerced via `unique_constraint` and logged as a non-fatal audit failure so the caller's main write still commits. Closes OPS-4601.
- Upgraded benchee 1.5.0->1.5.1 and credo 1.7.18->1.7.19 (within allowed ranges).

## [1.0.3] - 2026-05-28

### Fixed

- `*_and_log/*` and `log/*` no longer raise a `:rollback` `RuntimeError` when called from inside an `Ecto.Multi`. Closes OPS-3479.

## [1.0.2] - 2025-04-07

### Changed

- Refactor for performance and idiomatic Elixir (see git history).

## [Unreleased / prior]

See git log for earlier history (original author Nebo15 / Valiot).
