# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] - 2026-05-28

### Fixed
- **OPS-3476**: Prevent unexpected `:rollback` RuntimeError when `insert_and_log/3` (and siblings `update_and_log`, `delete_and_log`, `upsert_and_log`, `log/4`) are used from within `Ecto.Multi` pipelines (e.g. inside `Multi.run/2` callbacks in GraphQL mutations or other complex transactions). Root cause was unconditional `repo.transaction/0` wrapper creating nested transactions.
  - Added 5-arity (and supporting 4-arity for `log`) compose variants that append `Multi.insert`/`update`/... + changelog `Multi.run` step to an existing multi without forcing an inner transaction. Callers can now safely do `multi |> Repo.insert_and_log(:op, cs, actor, opts) |> Repo.transaction()`.
  - Refactored internal `log_changes*` and added `append_log_step/5` helper (kept simple per DHH principles, small named functions, no speculative generality).
  - Existing 3/4-arity execute APIs unchanged (now delegate to compose + tx for DRY).
  - Updated `__using__/1` delegations and docs.
  - Upgraded in-range deps (`ecto_sql`, `postgrex`, `credo`, `ex_doc`, transitives) per org policy.
- Added tests exercising the new compose path with `Ecto.Multi`.

### Changed
- Version bumped to 1.0.3.
- `mix.lock` refreshed with latest allowed dep versions.

[1.0.3]: https://github.com/valiot/ecto_trail/compare/v1.0.2...v1.0.3
