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
- **M3 real Grid/Filmstrip catalog browsing: COMPLETE, merged via PR #25, PR #26 and PR #27.**
- **M4 GPUI import/catalog mutations + authoritative persistence adapter: NEXT.**
- Active closeout branch: `feature/m3-closeout-evidence`.

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
- macOS GPUI resolves the Flutter App Sandbox projection location explicitly, with `DEXTRYX_CATALOG_PROJECTION_PATH` override support.

Reference: `docs/M2_AUTHORITATIVE_READ_ADAPTER.md`.

## M3 — real Grid/Filmstrip catalog browsing

Completed across PR #25, PR #26, and PR #27.

Production browser path:

```text
Flutter/Hive durable catalog authority
  -> disposable authoritative projection
  -> CatalogReadApplication
  -> DesktopAppState authoritative DTOs
  -> virtualized GPUI Grid + Filmstrip
  -> bounded disposable raster thumbnail cache
```

Completed M3 capabilities:

- stable `selected_asset_id` is shared by Grid and Filmstrip;
- selection survives refresh/filter when the same authoritative asset remains;
- deterministic fallback is used when selection disappears;
- horizontal Filmstrip renders only visible/overscan assets;
- Grid uses bounded viewport/overscan math over the same DTO collection;
- Grid and Filmstrip synchronize selection by stable asset ID;
- raster thumbnails are generated as pixel-bounded disposable PNGs before GPUI decode;
- thumbnail working set is capped at 64 IDs and generation attempts at 2 per sync;
- macOS uses `/usr/bin/sips` for the current GPUI production thumbnail generation path;
- generated browser thumbnail longest edge is bounded to 320 px;
- RAW/unsupported/missing assets remain explicit fallback-only paths in this milestone;
- no GPUI-specific durable catalog or thumbnail authority was introduced;
- no GPUI-to-Hive dependency was introduced.

PR #27 final exact head `6b7e797db1b9e82079578e2b9cbcb02873cf2ddc` passed:

- CI #483
- GPUI Production Shell #55
- Full validation #93

PR #27 squash-merged to `main` as `ada6a813e7fadb7c458db0f9984e38c00e4e4c86`.

Reference: `docs/M3_CATALOG_BROWSING.md`.

## M4 — GPUI import/catalog mutations + authoritative persistence adapter

M4 is the next implementation milestone.

Goal:

- move GPUI beyond read-only projection browsing without creating a second durable catalog;
- expose frontend-neutral mutation application services for import and catalog operations;
- preserve current linked/managed semantics, duplicate safety, staging/rollback, missing/relink and catalog-only removal rules;
- introduce exactly one authoritative persistence boundary usable from Rust without GPUI coupling;
- keep Flutter/Hive authoritative until the replacement adapter is explicitly validated and cut over;
- avoid image-processing/RAW scope in M4.

Recommended M4 slice order:

1. define mutation commands/results in `dextryx-frontend-api` without GPUI types;
2. add authoritative persistence port/adapter contract around existing catalog semantics;
3. wire GPUI Import command to shared Rust import orchestration, initially against a test/in-memory authority;
4. implement linked import persistence path;
5. implement managed import persistence path with staging/rollback parity;
6. add relink and catalog-only removal mutations;
7. validate cross-frontend/catalog parity before any durable-authority cutover;
8. document migration/cutover and rollback plan.

Do **not** make GPUI write the existing TSV read projection as an authority. The projection remains disposable read transport only.

## Migration queue

```text
DONE      M0 frontend-neutral Rust architecture foundation
DONE      M1 production GPUI bootstrap + command/state shell
DONE      M2 read-only authoritative Workplace/catalog adapter
DONE      M3 real Grid/Filmstrip catalog browsing
CURRENT   M4 import/catalog mutations + authoritative persistence adapter
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
docs/PROJECT_HANDOFF.md               canonical current status / execution queue
docs/FRONTEND_NEUTRAL_CORE.md         mandatory frontend-neutral Rust core contract
docs/M0_FRONTEND_API_FOUNDATION.md    completed M0 foundation and evidence
docs/M1_GPUI_PRODUCTION_SHELL.md      completed M1 implementation and acceptance evidence
docs/M2_AUTHORITATIVE_READ_ADAPTER.md completed M2 read-path design/evidence
docs/M3_CATALOG_BROWSING.md           completed M3 browser design/acceptance evidence
docs/GPUI_ARCHITECTURE_REVIEW.md      GPUI architecture evidence / migration decision
docs/GPUI_DESKTOP_SPIKE.md            experiment implementation and validation
docs/GPUI_S4_COMPATIBILITY.md         compatibility/platform gate
docs/CODE_WALKTHROUGH.md              production code ownership / data flow
docs/W4_DESKTOP_VALIDATION.md         outstanding physical W4 validation
docs/CI_ARCHITECTURE.md               CI contract
```

## Immediate execution order

```text
DONE      merge M3 PR #27 into main
CURRENT   close M3 documentation/evidence on feature/m3-closeout-evidence
NEXT      merge M3 closeout PR after green CI/review
NEXT      branch M4 mutation/persistence foundation from merged main
NEXT      define frontend-neutral mutation API + persistence port
PARALLEL  W4 physical D1-D8 desktop evidence remains outstanding
```
