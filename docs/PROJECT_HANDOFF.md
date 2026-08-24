# Dextryx Images — Project Handoff

> Canonical current status and execution queue for `dexter-cnx/nixin`.

## Current status

- Product: **Dextryx Images**
- Compact app label: **Dxtr Imgs**
- Canonical application/bundle ID: `com.cnxdev.dextryx.images`
- Repository remains `dexter-cnx/nixin`
- Studio workspace UI-01 through UI-15: complete
- W1 Workplace Core: complete
- W2 Import System + live Workplace wiring: complete
- W3 Workplace Browser + Filmstrip: complete
- W4-A missing/relink/catalog-removal hardening: complete
- W4-B1 managed/import recovery: complete
- W4-B2 thumbnail/cache + large-catalog hardening: complete
- W4 desktop physical/manual validation remains outstanding as a separate validation track.
- New image-processing / real sensor RAW demosaic work remains deferred.

## Current architectural direction

**Proceed with GPUI as the preferred native desktop frontend, while keeping the authoritative Rust core frontend-neutral.**

GPUI is a presentation/application-shell technology. It must not become the owner of domain, catalog, storage, import, thumbnail/cache, metadata, or image-processing semantics.

Flutter remains a viable future frontend through an FFI boundary. The product core must therefore remain reusable from GPUI, Flutter, CLI/tests, and other future consumers.

Canonical dependency contract:

```text
GPUI desktop ──────────────┐
                          │
Flutter -> FFI ───────────┼──> frontend/application API ──> Rust core
                          │                               ├─ Workplaces/catalog
CLI/tests ────────────────┘                               ├─ import orchestration
                                                          ├─ storage contracts
                                                          ├─ thumbnail/cache policy
                                                          ├─ metadata
                                                          └─ image engine

frontends/platform hosts ──> platform ports/adapters
```

Dependencies may point inward toward the core. Core/application/platform contract crates must never depend on GPUI, Flutter, Dart, FFI bindings, or frontend-only adapters.

Full mandatory rules: `docs/FRONTEND_NEUTRAL_CORE.md`.

## GPUI spike status

Active experiment branch: `agent/gpui-desktop-spike`.

Validated architecture evidence includes:

- native GPUI desktop application on macOS;
- direct Rust-to-Rust image-engine call path;
- image viewport interaction;
- 5,000-asset Filmstrip/catalog-like virtualization;
- bounded thumbnail work and cache behavior;
- framework-neutral catalog repository contract;
- stable asset identity across filters;
- linked/managed effective-path semantics;
- relink preserving identity;
- catalog-only removal semantics;
- active Workplace selection outside GPUI-specific domain state.

The experiment is evidence for the architecture, not yet the production persistence implementation.

## M0 implementation now present

The first production-neutral Rust boundaries now exist on this branch:

```text
experiments/gpui-desktop
        |
        +--> crates/dextryx-frontend-api --> crates/dextryx-core
        |           |
        |           +--> crates/dextryx-platform
        |
        +--> crates/dextryx-platform
```

`dextryx-core` owns extracted catalog/domain rules. `dextryx-frontend-api` owns frontend DTOs, commands/events, runtime-neutral long-operation contracts, and the first shared Import execution slice. `dextryx-platform` owns neutral platform/filesystem ports and a `std` filesystem implementation.

A shared Rust workspace exists at `crates/Cargo.toml` containing `dextryx-core`, `dextryx-frontend-api`, and `dextryx-platform`. Both the shared workspace and GPUI experiment have committed Cargo lockfiles.

Long-running operation infrastructure includes:

- stable `OperationId`;
- `OperationKind` for Import / Thumbnail / DevelopPreview;
- Started / Progress / ItemCompleted / Failed / Cancelled / Completed events;
- `OperationEventSink` usable by plain Rust closures or frontend adapters;
- cooperative `CancellationToken` implemented with Rust `std` primitives only.

Platform infrastructure includes:

- `FileDialogRequest`;
- `FileDialogPort`;
- `FileSystemPort` including file-type validation;
- `StdFileSystem`;
- GPUI-local `RfdFileDialogAdapter`;
- `rfd-backend` as a frontend-local dependency;
- a transitional GPUI compatibility entrypoint routing legacy picker syntax through `FileDialogPort`.

## First real long-running shared slice — Import execution

`dextryx-frontend-api` now contains `execute_import()` with framework-neutral request/result/port types:

```text
ImportExecutionRequest
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

The slice mirrors safety behavior already present in the production Flutter ImportController without duplicating persistence authority:

- linked and managed storage modes;
- duplicate source skip through `ImportCatalogPort`;
- catalog lookup errors fail the item before mutation;
- source-file validation;
- managed roots must already exist and are not silently recreated;
- managed-copy staging using a temporary `.part` path;
- existing managed destinations are never overwritten;
- partial-copy failures clean up staging artifacts;
- final rename only after copy succeeds;
- rollback of a newly copied managed original when catalog save fails;
- cooperative cancellation before mutation and at managed-copy safe points;
- progress/item/completed/failed/cancelled operation events;
- mixed-success summary and recoverable all-failed terminal status.

Contract tests cover duplicate prevention, catalog lookup failure, missing managed root, destination collision, partial-copy cleanup, managed-copy rollback, and cancellation-before-mutation.

The existing Flutter `ImportController` remains the production authority for batch persistence, retry/recovery, preferences, Hive repositories, and current UI state. Rust does **not** yet create a second durable import batch format.

## Frontend-neutral core guardrails

The following are hard architecture rules for production migration:

- no `gpui::Entity`, `Context`, `Window`, `Task`, action, subscription, or render type in shared core/application/platform contract crates;
- GPUI owns view/window/focus/shortcut/presentation state only;
- catalog identity and linked/managed semantics remain core rules;
- import duplicate prevention/recovery remains shared application/domain behavior;
- cache validity/invalidation policy remains shared behavior;
- image-processing semantics remain Rust engine/core behavior;
- long-running operations expose runtime-neutral progress/results/events;
- platform access is expressed through neutral ports and frontend/platform adapters;
- future Flutter integration maps the stable frontend API through FFI instead of calling GPUI;
- the FFI layer is a translation boundary, not a second application layer;
- do not redesign core models around Dart DTOs;
- do not connect GPUI directly to Hive;
- do not create a second durable catalog format.

## Production crate boundary target

```text
crates/
  dextryx_core/          domain + application rules
  dextryx_storage/       persistence contracts/adapters
  dextryx_image_engine/  image/RAW processing authority
  dextryx_thumbnail/     thumbnail/cache scheduling and policy
  dextryx_platform/      filesystem / OS adapter boundaries
  dextryx_frontend_api/  stable commands, DTOs and events
  dextryx_ffi/           optional Flutter bridge only

apps/
  desktop_gpui/          GPUI application shell / presentation
  flutter/               optional future Flutter frontend
```

Exact names may evolve; dependency direction must not.

## Promotion rule from GPUI experiment

```text
1. identify domain/application behavior
2. move/implement it in frontend-neutral Rust
3. add framework-independent tests
4. expose it through stable frontend/application API
5. integrate that API into GPUI presentation state
6. add Flutter/FFI mapping only if needed
```

Do not port by copying business logic into GPUI widgets.

## M0 — architecture foundation acceptance gate

M0 is intentionally limited to proving the frontend-neutral foundation. Full production storage/thumbnail/image-engine migration belongs to later milestones.

- [x] GPUI dependencies exist only in frontend/app crates for new shared Rust boundaries.
- [x] Shared core/application/platform crates compile independently of GPUI by construction.
- [x] Extracted domain models contain no GPUI types.
- [x] Frontend-facing commands/DTOs/events are framework-neutral.
- [x] At least one real long-running shared operation uses runtime-neutral progress/cancellation: Import execution.
- [x] Promoted file-dialog/import filesystem access is behind neutral ports/adapters.
- [x] A future Flutter/FFI frontend can target the same frontend/application API without GPUI.
- [x] CI includes a transitive dependency-policy guard preventing frontend-framework dependencies from entering protected shared crates.
- [x] Shared and GPUI Cargo lockfiles are committed.
- [ ] Strict `--locked` GPUI S4 Windows/Linux validation passes after restoration of the lock gate.

The remaining authoritative storage adapter, folder scan/thumbnail migration, and additional image-engine extraction are explicitly M2-M5 work and are not M0 blockers.

## Migration queue

```text
CURRENT   M0 final strict --locked S4 validation
NEXT      M1 production GPUI bootstrap + command/state shell
THEN      M2 read-only authoritative Workplace/catalog adapter
THEN      M3 real Grid/Filmstrip catalog browsing
THEN      M4 import/catalog mutations + authoritative import persistence adapter
THEN      M5 Develop controls around existing Rust engine
THEN      M6 desktop export/settings/polish
THEN      M7 retire Flutter desktop only after parity/validation gates
OPTIONAL  future Flutter frontend through FFI using the same Rust core
```

The migration remains incremental. Existing Flutter production paths stay buildable until corresponding GPUI behavior is validated and authoritative storage migration is explicitly approved.

## Persistence boundary

Production Flutter currently owns durable Workplaces/import persistence through repositories/adapters and Hive. Production storage migration remains a separate milestone.

Requirements:

- exactly one authoritative durable catalog format;
- no GPUI-specific persistence semantics;
- no direct GPUI-to-Hive coupling;
- storage implementation usable from frontend-neutral Rust application code;
- future Rust-native Dxtr_Box integration is evaluated as a storage milestone, not smuggled into UI migration.

## W4 physical validation track

W4 implementation/code gates are complete, but real desktop D1-D8 evidence remains outstanding and must not be claimed as passed without physical validation.

Reference: `docs/W4_DESKTOP_VALIDATION.md`.

## Regression gates

GPUI migration must preserve existing capabilities until explicitly replaced or deferred:

- embedded RAW preview behavior;
- raster preview;
- Develop adjustments;
- Subject/Sky masks;
- LUT;
- JPEG export;
- Workplace/catalog identity and persistence semantics;
- linked/managed safety;
- missing/relink behavior;
- import recovery and duplicate safety;
- thumbnail/cache safety.

## Documentation map

```text
docs/PROJECT_HANDOFF.md             canonical current status / execution queue
docs/FRONTEND_NEUTRAL_CORE.md       mandatory frontend-neutral Rust core contract
docs/M0_FRONTEND_API_FOUNDATION.md  M0 implementation status and remaining gates
docs/GPUI_ARCHITECTURE_REVIEW.md    GPUI architecture evidence / migration decision
docs/GPUI_DESKTOP_SPIKE.md          spike implementation and validation
docs/GPUI_S4_COMPATIBILITY.md       compatibility/platform gate
docs/CODE_WALKTHROUGH.md            production code ownership / data flow
docs/W4_DESKTOP_VALIDATION.md       outstanding physical W4 validation
docs/CI_ARCHITECTURE.md             CI contract
```

## Immediate execution order

```text
DONE      lock GPUI as preferred desktop frontend direction
DONE      define mandatory frontend-neutral dependency contract
DONE      extract catalog/domain semantics into dextryx-core
DONE      establish dextryx-frontend-api application boundary
DONE      define runtime-neutral operation/progress/cancellation contract
DONE      introduce dextryx-platform ports + StdFileSystem + GPUI rfd adapter
DONE      route current GPUI file-picker runtime path through FileDialogPort
DONE      establish shared frontend-neutral Rust workspace
DONE      implement first real Import execution slice on neutral ports/contracts
DONE      validate shared Import/core/platform crates in CI and fix compile/contract/review issues
DONE      commit shared + GPUI Cargo lockfiles
CURRENT   pass strict --locked GPUI S4 Windows/Linux validation
NEXT      mark M0 complete and begin M1 production GPUI app shell
PARALLEL  W4 physical D1-D8 desktop evidence remains outstanding
```
