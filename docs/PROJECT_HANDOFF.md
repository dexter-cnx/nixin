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
- W4 desktop physical/manual D1-D8 validation remains outstanding as a parallel validation track.
- New image-processing / real sensor RAW demosaic work remains deferred.
- **M0 frontend-neutral Rust architecture foundation: COMPLETE, merged via PR #21.**
- **M1 production GPUI bootstrap + command/state shell: COMPLETE, merged via PR #22.**
- **M2 read-only authoritative Workplace/catalog adapter: COMPLETE, merged via PR #23 and PR #24.**
- **M3 real Grid/Filmstrip catalog browsing: CURRENT.**
- Active branch: `feature/m3-catalog-browsing`.

## Current architectural direction

Proceed with **GPUI as the preferred native desktop frontend** while keeping the authoritative Rust core frontend-neutral.

GPUI is presentation/application-shell technology. It must not own domain, catalog, storage, import, thumbnail/cache, metadata, or image-processing semantics.

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

## M0 — frontend-neutral Rust architecture foundation

Completed via PR #21.

Key evidence:

- `dextryx-core` owns extracted catalog/domain rules;
- `dextryx-frontend-api` owns stable frontend DTOs, commands/events, operation contracts, cancellation, and shared Import execution;
- `dextryx-platform` owns file-dialog/filesystem ports and `StdFileSystem`;
- protected shared crates reject GPUI/Flutter/FFI dependencies;
- Import execution enforces linked/managed semantics, duplicate prevention, managed-root availability, staging/cleanup, rollback, cancellation, and operation events.

Reference: `docs/M0_FRONTEND_API_FOUNDATION.md`.

## M1 — production GPUI bootstrap + command/state shell

Completed via PR #22.

Production app path:

```text
apps/desktop-gpui/
```

Key evidence:

- production `dextryx-desktop` GPUI package;
- plain-Rust `DesktopAppState` + `AppCommand` without GPUI types;
- frontend-neutral `AssetQuery` reused for catalog navigation;
- production `RfdFileDialogAdapter` implements `FileDialogPort`;
- dedicated GPUI production CI validates format, tests, Clippy, and macOS build.

Reference: `docs/M1_GPUI_PRODUCTION_SHELL.md`.

## M2 — read-only authoritative Workplace/catalog adapter

Completed across PR #23 and PR #24.

Production read path:

```text
Flutter/Hive durable authority
  -> disposable catalog projection cache
  -> dextryx-frontend-api std-only projection parser
  -> CatalogReadApplication
  -> production GPUI DTO/read state
```

Completed M2 capabilities:

- `CatalogReadRepository` is separated from mutation-capable `CatalogRepository`;
- `CatalogReadApplication<R>` exposes read-only Workplace/asset DTOs without repository escape hatch;
- `AuthoritativeCatalogProjection` + `ProjectionCatalogReadAdapter` preserve stable asset identity, linked/managed effective-path semantics, missing state, and deterministic import order;
- Flutter writes a disposable TSV read cache using existing authoritative repositories only;
- projection refresh follows Workplace changes, import completion, availability scans, relink, and catalog removal;
- production GPUI loads the authoritative projection at startup and explicit Refresh;
- production GPUI has no direct Hive or `dextryx-core` dependency;
- macOS GPUI resolves the Flutter App Sandbox projection location explicitly, with `DEXTRYX_CATALOG_PROJECTION_PATH` override support;
- final PR #24 head `ac90e67fc2b82dc034c268ab0c60cd31a6ecaeba` passed CI #464, GPUI Production Shell #39, and Full validation #77;
- PR #24 squash-merged to `main` as `8f57ba4dfc831547a09d75c125e8004f9173a538`.

Reference: `docs/M2_AUTHORITATIVE_READ_ADAPTER.md`.

## M3 — real Grid/Filmstrip catalog browsing

M3 is the active implementation milestone.

Goal:

- replace the M2 diagnostic asset list with production catalog browsing;
- preserve selection by stable asset ID across refresh/filter operations;
- provide a horizontally virtualized Filmstrip backed by authoritative asset DTOs;
- add a real Grid browser over the same authoritative read state;
- keep thumbnail/cache work bounded and frontend-neutral where semantics belong outside GPUI;
- do not introduce catalog mutations or new durable persistence in M3.

Current M3 slice on `feature/m3-catalog-browsing`:

- add stable `selected_asset_id` to plain-Rust `DesktopAppState`;
- preserve selection across projection refresh when the stable asset remains present;
- fall back deterministically to the first asset when the prior selection disappears;
- add testable horizontal Filmstrip scroll/overscan math;
- render only the visible authoritative Filmstrip window instead of all assets;
- asset cards use real DTO identity/path/storage/missing state;
- selected asset becomes the central browser focus.

Next M3 work:

1. validate the first production Filmstrip slice on CI and review;
2. add real catalog Grid virtualization over the same asset DTO state;
3. wire selection synchronization between Grid and Filmstrip;
4. add bounded production thumbnail loading/cache without copying synthetic spike business logic;
5. update `docs/CODE_WALKTHROUGH.md` and M3 acceptance evidence before merge.

## Migration queue

```text
DONE      M0 frontend-neutral Rust architecture foundation
DONE      M1 production GPUI bootstrap + command/state shell
DONE      M2 read-only authoritative Workplace/catalog adapter
CURRENT   M3 real Grid/Filmstrip catalog browsing
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
docs/M1_GPUI_PRODUCTION_SHELL.md    completed M1 implementation and acceptance evidence
docs/M2_AUTHORITATIVE_READ_ADAPTER.md completed M2 read-path design/evidence
docs/GPUI_ARCHITECTURE_REVIEW.md    GPUI architecture evidence / migration decision
docs/GPUI_DESKTOP_SPIKE.md          experiment implementation and validation
docs/GPUI_S4_COMPATIBILITY.md       compatibility/platform gate
docs/CODE_WALKTHROUGH.md            production code ownership / data flow
docs/W4_DESKTOP_VALIDATION.md       outstanding physical W4 validation
docs/CI_ARCHITECTURE.md             CI contract
```

## Immediate execution order

```text
DONE      merge M2 PR #24 into main
DONE      branch feature/m3-catalog-browsing from merged main
CURRENT   validate stable selection + authoritative virtualized Filmstrip slice
NEXT      add real catalog Grid virtualization
NEXT      synchronize Grid/Filmstrip selection
NEXT      add bounded production thumbnail loading/cache
NEXT      sync walkthrough + M3 acceptance evidence
PARALLEL  W4 physical D1-D8 desktop evidence remains outstanding
```
