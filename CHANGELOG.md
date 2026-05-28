# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] - 2026-05-28

### Fixed

- Fix `RuntimeError` ("operation :rollback is rolling back unexpectedly") raised from `EctoTrail` when used during `Ecto.Multi` transactions/rollbacks (e.g. in `jobs-femsa-prod` `upsertBulkWorkflows` path).
  The cause was direct `repo.rollback/1` inside the internal `transaction` fun in `log_bulk/5`.
  Changed to return `{:error, reason}` from the fun so Ecto's wrapper handles rollback (see `Ecto.Repo.Transaction.transact` and multi error paths).
  Also upgraded some dependencies in the same PR.
  Closes OPS-3478.

  Note: nested transactions with `Ecto.Multi` are still discouraged by Ecto; the `_and_log` / `log*` helpers start their own transactions for atomicity of op+audit. For complex multis, consider performing main ops in the multi and logging after, or flattening.

## [1.0.2] - 2024-xx-xx

- Various refactors and log_bulk improvements (see git history).

