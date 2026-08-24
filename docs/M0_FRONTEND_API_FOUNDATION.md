# M0 — Frontend-Neutral API Foundation

Status: IN PROGRESS
Branch: `agent/gpui-desktop-spike`

## Completed

- Added `crates/dextryx-core` as a GPUI-free Rust domain/catalog crate.
- Moved catalog identity, linked/managed storage semantics, filtering, relink, catalog-only removal, active Workplace state and synthetic architecture-test repository out of the GPUI experiment.
- Added `crates/dextryx-frontend-api` as the stable frontend-facing application boundary.
- Added frontend DTOs, queries, mapped errors, catalog commands/events, runtime-neutral operation events and cooperative cancellation.
- Added `crates/dextryx-platform` with `FileDialogPort`, `FileDialogRequest`, `FileSystemPort`, and `StdFileSystem`.
- Added GPUI-local `RfdFileDialogAdapter`; upstream `rfd` is a GPUI implementation detail only.
- Added shared Rust workspace `crates/Cargo.toml`.
- Added `cargo metadata` dependency guard protecting `dextryx-core`, `dextryx-frontend-api`, and `dextryx-platform` from GPUI/Flutter/FFI dependencies.
- Added framework-independent tests for core, frontend API, platform ports, operation events, and cancellation.
- Added the first real long-running shared Rust slice: `execute_import()` in `dextryx-frontend-api`.
- `execute_import()` consumes `FileSystemPort`, `ImportCatalogPort`, `CancellationToken`, and `OperationEventSink` rather than GPUI/Dart APIs.
- Import execution currently covers linked/managed mode, duplicate skip, source-file validation, managed copy, temporary `.part` staging, rollback on catalog-save failure, progress events, failure summary, and cooperative cancellation cleanup.
- Added import regression tests for duplicate prevention, managed-copy rollback, and cancellation-before-mutation.

## Current dependency direction

```text
GPUI production dependency
        |
        +--> dextryx-frontend-api --> dextryx-core
        |           |
        |           +--> dextryx-platform
        |
        +--> dextryx-platform

GPUI-local adapters
        |
        +--> FileDialogPort -> RfdFileDialogAdapter -> rfd-backend
        +--> GPUI / native desktop APIs
```

A future Flutter frontend should enter at `dextryx-frontend-api` through an FFI translation crate and supply its own platform adapters.

## Import slice boundary

The existing Flutter `ImportController` remains the current production authority for batch persistence, retry/recovery, preferences, and Hive repositories.

The new Rust slice intentionally extracts only execution semantics that can be shared safely:

```text
ImportExecutionRequest
  + candidates / asset IDs
  + workplace ID
  + linked | managed
  + managed root
        |
        v
execute_import()
  + FileSystemPort
  + ImportCatalogPort
  + CancellationToken
  + OperationEventSink
        |
        +--> ImportExecutionSummary
```

This preserves the production safety rules already present in Dart:

- duplicate sources are skipped rather than cataloged twice;
- managed originals are staged before final placement;
- a newly copied managed original is deleted when catalog persistence fails;
- cancellation does not intentionally leave a newly copied managed artifact behind;
- mixed success/failure can complete with a summary, while an all-failed import emits terminal failure.

Batch/retry persistence is not duplicated in Rust yet. That belongs to the authoritative storage migration milestone.

## Runtime-neutral operation rule

Long-running operations must not expose `gpui::Task`, GPUI entities, Tokio handles, or Dart Futures/Streams from shared crates.

```text
operation request + CancellationToken
        |
        v
shared Rust operation
        |
        +--> OperationEventSink
                 |
                 +--> GPUI adapter -> GPUI state/task
                 +--> future FFI adapter -> Dart Stream/Future
```

Cancellation is cooperative; shared Rust operations choose safe cancellation points.

## Platform boundary rule

Shared application/core code must not open dialogs or depend on frontend-specific filesystem APIs directly.

```text
shared application/core
        |
        +--> neutral platform/file-system ports
                     |
                     +--> GPUI adapter -> rfd / desktop filesystem
                     +--> Flutter adapter -> Flutter/native picker APIs
```

The current spike still uses a compatibility facade around its large legacy `main.rs`; the production GPUI shell should use the neutral adapter explicitly.

## Still pending for M0

- Regenerate and commit `experiments/gpui-desktop/Cargo.lock`; then restore strict `--locked` S4 commands.
- Validate the new shared import slice in CI on supported desktop runners.
- Add a concrete adapter from the future authoritative Rust catalog/storage implementation to `ImportCatalogPort`; do not connect GPUI directly to Hive.
- Extend filesystem migration to folder scanning/thumbnail work as those slices are promoted.
- Decide whether import batch/retry persistence belongs in a future `dextryx-storage` crate or another neutral persistence crate during M2/M4; do not create a second durable format.
- Remove the transitional GPUI file-dialog compatibility alias when the production GPUI shell replaces the spike entrypoint.

## M0 completion rule

M0 is complete only when shared catalog/application behavior is independently testable, protected from frontend-framework dependencies, platform access is behind replaceable ports, at least one real long-running operation uses the neutral operation contract, and the same API can serve GPUI plus a future Flutter/FFI frontend without redesigning the core.
