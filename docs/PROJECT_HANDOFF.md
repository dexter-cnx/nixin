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
- W4 desktop physical/manual D1-D8 validation remains outstanding as a separate validation track.
- New image-processing / real sensor RAW demosaic work remains deferred.
- **M0 frontend-neutral Rust architecture foundation: COMPLETE and merged via PR #21.**
- **M1 production GPUI bootstrap + command/state shell: CURRENT.**
- Active M1 branch: `feature/m1-gpui-production-shell`.

## Current architectural direction

Proceed with **GPUI as the preferred native desktop frontend** while keeping the authoritative Rust core frontend-neutral.

GPUI is a presentation/application-shell technology. It must not own domain, catalog, storage, import, thumbnail/cache, metadata, or image-processing semantics.

Flutter remains a viable future frontend through an FFI boundary. The same Rust core/application API must remain reusable from GPUI, Flutter, CLI/tests, and future consumers.

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

Dependencies point inward. Protected shared crates must never depend on GPUI, Flutter, Dart, FFI bindings, or frontend-only adapters.

Full rules: `docs/FRONTEND_NEUTRAL_CORE.md`.

## M0 completion evidence

M0 established the first production-neutral Rust boundaries:

```text
experiments/gpui-desktop
        |
        +--> crates/dextryx-frontend-api --> crates/dextryx-core
        |           |
        |           +--> crates/dextryx-platform
        |
        +--> crates/dextryx-platform
```

Completed M0 capabilities:

- `dextryx-core` owns extracted catalog/domain rules;
- `dextryx-frontend-api` owns stable frontend DTOs, commands/events, operation contracts, cancellation, and shared Import execution;
- `dextryx-platform` owns file-dialog/filesystem ports and `StdFileSystem`;
- shared workspace `crates/Cargo.toml` with committed `crates/Cargo.lock`;
- GPUI experiment has committed `experiments/gpui-desktop/Cargo.lock`;
- transitive dependency-policy guard prevents GPUI/Flutter/FFI dependencies entering protected shared crates;
- neutral `OperationEventSink` + `CancellationToken` support long-running operations without GPUI/Dart runtime types;
- GPUI-local `RfdFileDialogAdapter` implements `FileDialogPort`;
- shared Import execution enforces linked/managed semantics, duplicate prevention, managed-root availability, destination collision refusal, `.part` staging/cleanup, rollback, cancellation, and progress/failure events;
- regression tests cover duplicate lookup failure, missing managed root, destination collision, partial-copy cleanup, rollback, and cancellation-before-mutation;
- Rust 1.98 format/clippy gates pass;
- strict Cargo `--locked` validation restored for shared + GPUI workspaces;
- PR #21 final checks `CI #432` and `Full validation #48` passed;
- PR #21 squash-merged to `main` as `3f97d9b5b178a9f32f9575f5632ea0f013e93396`.

Reference: `docs/M0_FRONTEND_API_FOUNDATION.md`.

## GPUI spike role

`experiments/gpui-desktop` remains architecture evidence, not production persistence authority.

Validated spike evidence includes native GPUI macOS launch, direct Rust-to-Rust image-engine calls, viewport pan/zoom, a 5,000-asset virtualized Filmstrip, bounded thumbnail/cache work, framework-neutral catalog behavior, stable asset identity, linked/managed semantics, relink, catalog-only removal, and active Workplace state outside GPUI domain state.

Do not promote spike business logic by copying it into production GPUI widgets. Promote through the shared Rust API.

## M1 — production GPUI bootstrap + command/state shell

Production app path:

```text
apps/desktop-gpui/
```

Current M1 implementation:

- production Cargo package `dextryx-desktop` pinned to the proven GPUI/Zed revision;
- direct dependencies on `dextryx-frontend-api` and `dextryx-platform`;
- plain-Rust `DesktopAppState` + `AppCommand` in `src/app_state.rs` with no GPUI types;
- catalog navigation reuses `dextryx_frontend_api::AssetQuery`;
- initial GPUI Library/Develop shell in `src/main.rs`;
- Import UI exists only as a command placeholder; no GPUI-owned import logic was introduced;
- `make format` and changed-file Rust formatting cover `apps/desktop-gpui`;
- `.github/workflows/gpui-production.yml` validates format, unit tests, Clippy, and macOS build;
- detailed status: `docs/M1_GPUI_PRODUCTION_SHELL.md`.

### M1 non-goals

- no authoritative catalog storage migration yet;
- no direct GPUI-to-Hive coupling;
- no new durable catalog/import-batch format;
- no full Grid/Filmstrip migration yet (M3);
- no production import mutation/persistence migration yet (M4);
- no new Develop/RAW processing work yet (M5+);
- do not retire Flutter desktop in M1.

### M1 acceptance gate

- production GPUI app shell compiles on the supported macOS-first path;
- production shell depends inward on shared frontend/core/platform crates;
- no GPUI types enter protected shared crates;
- app command/state boundary is explicit and testable;
- production file-dialog path uses `FileDialogPort` directly;
- existing PR/CI architecture guards remain green;
- no second persistence authority is introduced.

## Migration queue

```text
DONE      M0 frontend-neutral Rust architecture foundation
CURRENT   M1 production GPUI bootstrap + command/state shell
NEXT      M2 read-only authoritative Workplace/catalog adapter
THEN      M3 real Grid/Filmstrip catalog browsing
THEN      M4 import/catalog mutations + authoritative import persistence adapter
THEN      M5 Develop controls around existing Rust engine
THEN      M6 desktop export/settings/polish
THEN      M7 retire Flutter desktop only after parity/validation gates
OPTIONAL  future Flutter frontend through FFI using the same Rust core
PARALLEL  W4 physical D1-D8 desktop evidence remains outstanding
```

## Persistence boundary

Production Flutter currently remains the durable Workplaces/import persistence authority through repositories/adapters and Hive.

Requirements for later storage migration:

- exactly one authoritative durable catalog format;
- no GPUI-specific persistence semantics;
- no direct GPUI-to-Hive coupling;
- storage implementation usable from frontend-neutral Rust application code;
- future Rust-native Dxtr_Box integration is evaluated as a storage milestone, not embedded into UI migration.

## Regression gates

GPUI migration must preserve embedded RAW preview behavior, raster preview, Develop adjustments, Subject/Sky masks, LUT, JPEG export, Workplace/catalog identity and persistence semantics, linked/managed safety, missing/relink behavior, import recovery/duplicate safety, and thumbnail/cache safety until explicitly replaced or deferred.

## Documentation map

```text
docs/PROJECT_HANDOFF.md             canonical current status / execution queue
docs/FRONTEND_NEUTRAL_CORE.md       mandatory frontend-neutral Rust core contract
docs/M0_FRONTEND_API_FOUNDATION.md  completed M0 foundation and evidence
docs/M1_GPUI_PRODUCTION_SHELL.md    current M1 implementation and acceptance gates
docs/GPUI_ARCHITECTURE_REVIEW.md    GPUI architecture evidence / migration decision
docs/GPUI_DESKTOP_SPIKE.md          experiment implementation and validation
docs/GPUI_S4_COMPATIBILITY.md       compatibility/platform gate
docs/CODE_WALKTHROUGH.md            production code ownership / data flow
docs/W4_DESKTOP_VALIDATION.md       outstanding physical W4 validation
docs/CI_ARCHITECTURE.md             CI contract
```

## Immediate execution order

```text
DONE      merge M0 PR #21 into main
DONE      branch feature/m1-gpui-production-shell from merged main
DONE      bootstrap apps/desktop-gpui production crate
DONE      add plain-Rust DesktopAppState/AppCommand boundary
DONE      add initial GPUI Library/Develop shell
DONE      add format + macOS production-shell CI coverage
CURRENT   validate M1 shell on PR CI and fix compile/format/clippy issues
NEXT      wire Import through FileDialogPort + frontend application boundary
NEXT      remove production dependence on any spike compatibility facade
PARALLEL  W4 physical D1-D8 desktop evidence remains outstanding
```
