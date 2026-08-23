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
- Added `tool/check-rust-core-dependencies.py` using `cargo metadata` to protect both `dextryx-core` and `dextryx-frontend-api` from GPUI/Flutter/FFI dependencies, including transitive dependencies.
- Updated GPUI S4 CI triggers/cache/tests to include both shared crates and the dependency guard.
- Added runtime-neutral long-operation contracts in `dextryx-frontend-api`: `OperationId`, `OperationKind`, started/progress/item/failure/cancel/completed events, `OperationEventSink`, and cooperative `CancellationToken`.
- Operation reporting can be consumed by a plain Rust closure today, by GPUI presentation adapters later, or mapped to a Dart Stream/Future bridge without changing the application contract.

## Current dependency direction

```text
GPUI production dependency
        |
        v
dextryx-frontend-api
        |
        v
dextryx-core
```

A future Flutter frontend should enter at `dextryx-frontend-api` through an FFI translation crate, never through GPUI.

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

## Still pending for M0

- Regenerate and commit `experiments/gpui-desktop/Cargo.lock` after the new local path crates are resolved; only then restore strict `--locked` S4 commands.
- Apply the runtime-neutral operation contract to the first real long-running slice rather than leaving it as contract-only infrastructure. Import is the preferred first candidate because production semantics already include progress/cancellation/recovery.
- Introduce platform/filesystem adapter boundaries where UI/platform calls would otherwise leak into application code.
- Replace synthetic GPUI catalog data with a read-only authoritative catalog adapter in the later persistence milestone; do not connect GPUI directly to Hive.
- Decide production workspace layout once the experimental crates are promoted; do not force a workspace reshuffle merely to satisfy M0 naming.

## M0 completion rule

M0 is not complete merely because GPUI can compile. It is complete when shared catalog/application behavior is independently testable, protected from UI-framework dependencies, and usable by both the GPUI frontend and a future Flutter/FFI adapter without redesigning the core.
