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
- **M0 frontend-neutral Rust architecture foundation: COMPLETE.**
- **M1 production GPUI bootstrap + command/state shell: CURRENT.**

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
- PR #21 acceptance validation: `CI #430` and `Full validation #46` green;
- strict locked GPUI S4 Windows/Linux validation passed, closing the final M0 gate.

Reference: `docs/M0_FRONTEND_API_FOUNDATION.md`.

## GPUI spike role

`experiments/gpui-desktop` remains architecture evidence, not production persistence authority.

Validated spike evidence includes:

- native GPUI desktop application on macOS;
- direct Rust-to-Rust image-engine path;
- viewport pan/zoom;
- 5,000-asset virtualized Filmstrip/catalog-like behavior;
- bounded thumbnail/cache work;
- framework-neutral catalog contract;
- stable identity across filters;
- linked/managed effective-path semantics;
- relink preserving identity;
- catalog-only removal;
- active Workplace state outside GPUI domain state.

Do not promote spike business logic by copying it into production GPUI widgets. Promote through the shared Rust API.

## M1 — production GPUI bootstrap + command/state shell

M1 starts now. Its purpose is to create the real desktop GPUI application shell on top of the M0 contracts without introducing a second persistence authority.

### M1 scope

- create a production GPUI app location separate from the experiment, targeting `apps/desktop_gpui` unless repository constraints require an equivalent path;
- wire the shell to `dextryx-frontend-api` and `dextryx-platform`;
- define GPUI-only presentation state for window/layout/focus/shortcuts;
- establish app commands/actions that translate into neutral frontend/application calls;
- use `FileDialogPort` explicitly; remove dependence on the transitional compatibility facade for production code;
- provide initial Workplace/catalog shell state using neutral DTOs/contracts only;
- preserve current image-engine call boundaries without new RAW/demosaic work;
- add production-shell tests where possible without requiring a graphical session;
- keep Flutter desktop buildable throughout M1.

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
docs/M0_FRONTEND_API_FOUNDATION.md  completed M0 foundation and evidence
docs/GPUI_ARCHITECTURE_REVIEW.md    GPUI architecture evidence / migration decision
docs/GPUI_DESKTOP_SPIKE.md          experiment implementation and validation
docs/GPUI_S4_COMPATIBILITY.md       compatibility/platform gate
docs/CODE_WALKTHROUGH.md            production code ownership / data flow
docs/W4_DESKTOP_VALIDATION.md       outstanding physical W4 validation
docs/CI_ARCHITECTURE.md             CI contract
```

## Immediate execution order

```text
DONE      M0 dependency contract / shared crates / neutral operations
DONE      M0 Import execution safety + regression tests
DONE      M0 Rust 1.98 format/clippy + PR review fixes
DONE      M0 shared + GPUI Cargo lockfiles and strict --locked validation
DONE      M0 PR validation green
CURRENT   design and bootstrap the production M1 GPUI app shell
NEXT      wire neutral command/state + direct FileDialogPort usage
NEXT      add non-graphical M1 shell contract tests and CI coverage
PARALLEL  W4 physical D1-D8 desktop evidence remains outstanding
```

PR #21 remains open and must not be merged until explicitly requested.
