# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] - 2026-05-28

### Fixed

- Prevent `RuntimeError` ("operation :rollback is rolling back unexpectedly") when `insert_and_log` / `update_and_log` / `upsert_and_log` / `delete_and_log` / `log` are invoked from inside an `Ecto.Multi.run` callback (which the platform does for all audited mutations and bulk upserts). Refactored internal implementations to use plain `repo.transaction/1` blocks instead of wrapping in `Ecto.Multi` before transacting; this avoids nested multi + rollback detection issues under deep transaction nesting as triggered by `upsertBulkWorkflows` and similar complex flows.

## [1.0.2] - 2023-??-??

### Added

- Bulk logging support via `log_bulk/5`.

## [0.2.0] - Older

Initial releases.
