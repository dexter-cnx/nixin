# M0 — Frontend-Neutral API Foundation

Status: VALIDATION GATE
Branch: `agent/gpui-desktop-spike`

## Completed

- Added `crates/dextryx-core` as a GPUI-free Rust domain/catalog crate.
- Moved catalog identity, linked/managed storage semantics, filtering, relink, catalog-only removal, active Workplace state and synthetic architecture-test repository out of the GPUI experiment.
- Added `crates/dextryx-frontend-api` as the stable frontend-facing application boundary.
- Added frontend DTOs, queries, mapped errors, catalog commands/events, runtime-neutral operation events and cooperative cancellation.
- Added `crates/dextryx-platform` with `FileDialogPort`, `FileDialogRequest`, `FileSystemPort`, and `StdFileSystem`.
- Added GPUI-local `RfdFileDialogAdapter`; upstream `rfd` is a GPUI implementation detail only.
- Added shared Rust workspace `crates/Cargo.toml` and committed `crates/Cargo.lock`.
- Added `cargo metadata` dependency guard protecting `dextryx-core`, `dextryx-frontend-api`, and `dextryx-platform` from GPUI/Flutter/FFI dependencies.
- Added framework-independent tests for core, frontend API, platform ports, operation events, and cancellation.
- Added the first real long-running shared Rust slice: `execute_import()` in `dextryx-frontend-api`.
- `execute_import()` consumes `FileSystemPort`, `ImportCatalogPort`, `CancellationToken`, and `OperationEventSink` rather than GPUI/Dart APIs.
- Import execution covers linked/managed mode, duplicate skip, source-file validation, managed-copy staging, collision refusal, rollback on catalog-save failure, partial-copy cleanup, managed-root availability checks, progress events, failure summary, and cooperative cancellation cleanup.
- Duplicate catalog lookup failures stop that item before filesystem/catalog mutation.
- Added regression tests for duplicate prevention, catalog lookup failure, missing managed root, managed destination collision, partial-copy cleanup, managed-copy rollback, and cancellation-before-mutation.
- Rust 1.98 format/clippy gates and the full repository CI currently pass on PR #21 before the final locked-S4 validation change.
- `experiments/gpui-desktop/Cargo.lock` is committed and strict `--locked` commands are restored in GPUI S4 compatibility validation.

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

Safety rules now enforced by the shared slice:

- duplicate sources are skipped rather than cataloged twice;
- catalog lookup errors fail the item instead of being interpreted as "not duplicate";
- a configured managed root must already exist and is never silently recreated;
- existing managed destinations are never overwritten;
- managed originals are staged before final placement;
- failed or partial managed copies remove the `.part` artifact;
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

## M0 acceptance gate

M0 is scoped to proving the frontend-neutral architecture foundation, not completing the later storage/thumbnail/image-engine migrations.

- [x] Shared catalog/domain behavior is independently testable without GPUI.
- [x] Frontend-facing commands/DTOs/events are framework-neutral.
- [x] Platform access used by the promoted file-dialog/import slice is behind replaceable ports/adapters.
- [x] At least one real long-running operation uses runtime-neutral progress/cancellation.
- [x] The same application API can serve GPUI and a future Flutter/FFI frontend without redesigning the core.
- [x] CI enforces the transitive dependency boundary for protected shared crates.
- [x] Shared and GPUI Cargo lockfiles are committed.
- [ ] Strict `--locked` S4 Windows/Linux validation passes after restoration of the lock gate.

Once the final locked S4 validation is green, M0 is complete and M1 can begin.

## Deferred migration work — not M0 blockers

- Add a concrete adapter from the future authoritative Rust catalog/storage implementation to `ImportCatalogPort`; do not connect GPUI directly to Hive. Target: M2/M4.
- Extend filesystem/platform migration to folder scanning and thumbnail work when those slices are promoted. Target: M3/M4.
- Decide placement of authoritative import batch/retry persistence in a future neutral storage crate. Target: M2/M4.
- Remove the transitional GPUI file-dialog compatibility alias when the production GPUI shell replaces the spike entrypoint. Target: M1.
- Extract additional image-processing/storage/thumbnail crates only as their production slices are promoted; they are not required to prove M0 architecture viability.

## M1 entry condition

Begin the production GPUI application shell only after the strict locked S4 gate is green. M1 should consume the stable frontend/application API and neutral platform ports rather than copying business logic from the experiment.
