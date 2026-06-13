# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-06-13

### Fixed

- `update_and_log` (and other `*_and_log`) no longer raise `Ecto.ConstraintError` on `audit_log_pkey` (or custom table pkey) when the audit_log sequence is ahead of or reuses an id (e.g. explicit id seed, replay inside outer tx, or sequence skew in prod). Added `unique_constraint/3` declaration on the internal Changelog changeset using the runtime table name so Ecto converts the violation to a changeset error; existing error handling in `log_changes` swallows it (logs + continues) exactly as other audit failures. Closes OPS-4627.

## [1.0.3] - 2026-05-28

### Fixed

- `*_and_log/*` and `log/*` no longer raise a `:rollback` `RuntimeError` when called from inside an `Ecto.Multi`. Closes OPS-3479.

## [1.0.2] - 2025-04-07

### Changed

- Refactor for performance and idiomatic Elixir (see git history).

## [Unreleased / prior]

See git log for earlier history (original author Nebo15 / Valiot).
