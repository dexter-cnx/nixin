# M0 — Frontend-Neutral API Foundation

Status: IN PROGRESS
Branch: `agent/gpui-desktop-spike`

## Completed

- Added `crates/dextryx-core` as a GPUI-free Rust domain/catalog crate.
- Moved catalog identity, linked/managed storage semantics, filtering, relink, catalog-only removal, active Workplace state and the synthetic architecture-test repository out of the GPUI experiment.
- Added framework-independent contract tests under `crates/dextryx-core/tests`.
- Added `crates/dextryx-frontend-api` as the stable frontend-facing application boundary.
- Added frontend DTOs, queries, mapped API errors and neutral mutation events.
- Added `CatalogApplication<R>` operations for Workplace listing, asset listing/filtering, active Workplace changes, relink and catalog-only removal.
- Added frontend-API contract tests independent from GPUI.
- GPUI boundary tests now call `dextryx-frontend-api`; the GPUI package no longer has `dextryx-core` as a production dependency. `dextryx-core` remains a dev-dependency only for constructing the synthetic test adapter.
- Added `tool/check-rust-core-dependencies.py` using `cargo metadata` to protect `dextryx-core`, `dextryx-frontend-api`, and `dextryx-platform` from GPUI/Flutter/FFI dependencies, including transitive dependencies.
- Updated GPUI S4 CI triggers/cache/tests to include all three shared crates and the dependency guard.
- Added runtime-neutral long-operation contracts in `dextryx-frontend-api`: `OperationId`, `OperationKind`, started/progress/item/failure/cancel/completed events, `OperationEventSink`, and cooperative `CancellationToken`.
- Operation reporting can be consumed by a plain Rust closure today, by GPUI presentation adapters later, or mapped to a Dart Stream/Future bridge without changing the application contract.
- Added `crates/dextryx-platform` with frontend-neutral `FileDialogPort`, `FileDialogRequest`, `FileSystemPort`, and `StdFileSystem`.
- Added platform contract tests covering dialog request shape plus basic filesystem operations without GPUI or Flutter.
- Added GPUI-local `RfdFileDialogAdapter` under `experiments/gpui-desktop/src/file_dialog.rs`; upstream `rfd` is now named `rfd-backend` in the GPUI package so it is clearly an implementation detail.
- Added a GPUI compatibility facade and explicit `src/entry.rs` binary entrypoint. The existing spike `main.rs` still contains its legacy `use rfd::FileDialog` syntax, but at compile time that name now resolves to the local facade, which delegates through `FileDialogPort -> RfdFileDialogAdapter -> rfd-backend`.
- Added `crates/Cargo.toml` as the shared frontend-neutral Rust workspace for `dextryx-core`, `dextryx-frontend-api`, and `dextryx-platform`.

## Current dependency direction

```text
GPUI production dependency
        |
        +--> dextryx-frontend-api --> dextryx-core
        |
        +--> dextryx-platform

GPUI-local adapters
        |
        +--> FileDialogPort -> RfdFileDialogAdapter -> rfd-backend
        +--> GPUI / native desktop APIs
```

A future Flutter frontend should enter at `dextryx-frontend-api` through an FFI translation crate and provide its own platform/file-picker adapters rather than calling GPUI adapters.

## Runtime-neutral operation rule

Long-running operations such as Import, thumbnail generation and Develop preview must not expose `gpui::Task`, GPUI entities, Tokio handles, or Dart Futures/Streams from shared application/core crates.

They should use the neutral contract:

```text
operation request
    + OperationId
    + CancellationToken
        |
        v
shared Rust operation
        |
        +--> OperationEventSink
                 |
                 +--> GPUI adapter -> GPUI state/task
                 |
                 +--> future FFI adapter -> Dart Stream/Future
```

Cancellation is cooperative. The frontend requests cancellation through `CancellationToken`; Rust operations decide safe stopping points and emit `OperationEvent::Cancelled` when termination has actually occurred.

## Platform boundary rule

Shared application/core code must not open dialogs or call frontend-specific filesystem APIs directly.

```text
shared application/core
        |
        +--> neutral platform/file-system ports
                     |
                     +--> GPUI adapter -> rfd / desktop filesystem
                     |
                     +--> Flutter adapter -> Flutter/native picker APIs
```

The dialog-selection mechanism and filesystem implementation are replaceable adapters. Catalog/import semantics must remain outside those adapters.

The current spike uses a compatibility entrypoint rather than rewriting the large experimental `main.rs` only to replace one import. This is transitional spike infrastructure; the production GPUI shell should import the neutral port/adapter explicitly instead of carrying the compatibility alias forward.

## Still pending for M0

- Regenerate and commit `experiments/gpui-desktop/Cargo.lock` after the new local path crates are resolved; only then restore strict `--locked` S4 commands.
- Apply the runtime-neutral operation contract to the first real long-running slice rather than leaving it as contract-only infrastructure. Import is the preferred first candidate because production semantics already include progress/cancellation/recovery.
- Route real import/thumbnail filesystem work through `FileSystemPort` as those slices move into shared Rust; do not merely wrap every `std::fs` call without preserving domain ownership.
- Replace synthetic GPUI catalog data with a read-only authoritative catalog adapter in the later persistence milestone; do not connect GPUI directly to Hive.
- Validate the new GPUI entrypoint/compatibility facade through CI and remove the compatibility alias when the production GPUI shell replaces the spike entrypoint.

## M0 completion rule

M0 is not complete merely because GPUI can compile. It is complete when shared catalog/application behavior is independently testable, protected from UI-framework dependencies, platform access is behind replaceable adapters, and the same application contracts can serve GPUI plus a future Flutter/FFI frontend without redesigning the core.
