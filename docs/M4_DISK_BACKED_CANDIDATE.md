# M4 Disk-Backed Catalog Candidate

Status: qualification-only. This adapter is not authorized as the durable catalog authority.

## Purpose

`DiskCandidateCatalogStore` is the first Rust catalog candidate that survives a process-style close/reopen cycle. It exists to prove disk snapshot round-trip and persisted mutation semantics before any authority cutover.

Flutter/KeyValueStore/Hive remains the sole durable catalog authority.

## What this slice proves

- validated `AuthoritativeCatalogProjection` can be written to a private disk snapshot;
- the snapshot can be reopened and reconstructed without losing Workplace/asset identity or storage semantics;
- active Workplace and relink mutations survive a close/reopen cycle;
- corrupt snapshot input is rejected;
- the same shared snapshot/invariant boundaries remain in use.

## Deliberately unproven capabilities

The candidate reports these as false:

- `atomic_commit`
- `crash_recovery`
- `durable_flush`
- `single_writer_enforced`
- `rollback_supported`

It reports only snapshot round-trip and mutation parity as demonstrated.

Therefore `is_cutover_ready()` remains false by construction.

## Persistence format

The candidate uses a private versioned binary snapshot (`DXTRCAT1`) inside `dextryx-storage`.

This is not a public interchange format and is not the existing read-projection TSV. Paths must be valid UTF-8; unsupported/non-UTF-8 paths are rejected rather than silently rewritten.

The current replacement sequence writes a `.next` file, calls `sync_all()` on that file, then replaces the destination. Cross-platform atomic replacement and parent-directory durability are intentionally not claimed yet.

## Mutation-port guardrail

`DiskCandidateCatalogStore` intentionally does **not** implement `AuthoritativeCatalogPersistence` in this slice.

Reason: the current mutation port returns `CatalogRepositoryError`, which represents catalog/domain lookup failures but has no typed persistence/I/O failure. A disk authority must not hide durability failures inside an unrelated domain error.

Before promotion, the mutation contract must gain an explicit persistence-failure channel and all frontend mappings must preserve it.

## Next qualification slice

1. Extend the authoritative mutation error model with typed persistence failures.
2. Add failure injection around write, sync, replace and reopen boundaries.
3. Implement proven atomic replacement semantics for supported platforms.
4. Add single-writer locking/ownership.
5. Add rollback/recovery generation handling.
6. Only then allow the disk candidate to implement `AuthoritativeCatalogPersistence` and re-evaluate the seven cutover requirements.

No GPUI durable mutation wiring is allowed before that gate passes.
