# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] - 2026-05-28

### Fixed

- **Critical**: `EctoTrail.*_and_log/*` and `log/*` functions could raise
  `(RuntimeError) operation :rollback is rolling back unexpectedly` when
  invoked from inside an `Ecto.Multi` (e.g. `Multi.run` steps during bulk
  upserts like `upsertBulkWorkflows`). This was caused by the internal
  `run_logging_transaction/*` helpers building and immediately transacting
  an `Ecto.Multi` while the caller was already inside an outer `Ecto.Multi`
  transaction — a pattern Ecto explicitly forbids (see Ecto.Repo.Transaction
  and the nested-tx guidance in the raised message). The stacktrace always
  pointed at `ecto_trail.ex:342`.

  Refactored the four `*_and_log` implementations to perform the primary
  operation + changelog insert inside a single `repo.transaction(fn tx -> … end)`
  (the form that supports `repo.rollback/1`). The standalone `log/5` now
  performs the changelog insert directly (no forced transaction) so it
  participates cleanly in any caller transaction. Logging-failure swallowing
  semantics are preserved exactly.

  This makes the library safe and correct to use from within larger
  `Ecto.Multi` workflows while keeping the original "single call = atomic
  op+log" guarantees for standalone use.

  Closes OPS-3479.

## [1.0.2] - 2025-04-07

### Changed

- Refactor for performance and idiomatic Elixir (see git history).

## [Unreleased / prior]

See git log for earlier history (original author Nebo15 / Valiot).
