# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] - 2026-05-28

### Fixed
- Wrap audit logging inserts (`log_changes/5`, `log_changes_alone/6`) in `try/rescue` so that `DBConnection.ConnectionError` (and any other exceptions during prep or `repo.insert`) are caught, logged via `Logger.error`, and turned into non-fatal `{:ok, reason}` returns from the `Ecto.Multi.run` step. This prevents closed/stale DB connections (or transient errors) during audit logging from rolling back the caller's main `Ecto.Multi` transaction (e.g. `upsertBulkWorkflows` bulk mutations) or surfacing as 500s. Audit logging remains best-effort.
  - Previously, exceptions in the logging step would propagate out of the Multi, failing the entire operation (see OPS-3480 stacktrace at ecto_trail.ex:420).
  - Matches the existing error-tuple handling and the top-level `rescue` in `log_bulk/5`.
- Updated dev/test and runtime dependencies within their allowed version ranges (credo, ecto_sql, ex_doc, postgrex + transitive).

### Changed
- No behavior change for happy path or normal error tuples from inserts.
- Added TDD test covering the exception path for `log/5`.

Closes OPS-3480

## [1.0.2] - 2025-xx (previous)

See git history for prior changes (batch logging, performance refactor, etc.).
