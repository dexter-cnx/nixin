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
```

Dependencies may point inward toward the core. Core crates must never depend on GPUI, Flutter, Dart, or FFI bindings.

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

## Frontend-neutral core guardrails

The following are hard architecture rules for production migration:

- no `gpui::Entity`, `Context`, `Window`, `Task`, action, subscription, or render type in shared core crates;
- GPUI owns view/window/focus/shortcut/presentation state only;
- catalog identity and linked/managed semantics remain core rules;
- import duplicate prevention/recovery remains core behavior;
- cache validity/invalidation policy remains core behavior;
- image-processing semantics remain Rust engine/core behavior;
- long-running operations expose runtime-neutral progress/results/events;
- future Flutter integration maps the stable frontend API through FFI instead of calling GPUI;
- the FFI layer is a translation boundary, not a second application layer;
- do not redesign core models around Dart DTOs;
- do not connect GPUI directly to Hive;
- do not create a second durable catalog format.

## Production crate boundary target

Exact names may evolve, but production migration should converge toward responsibilities equivalent to:

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

## Promotion rule from GPUI experiment

Do not port by copying business logic into GPUI widgets.

For each vertical slice:

```text
1. identify domain/application behavior
2. move/implement it in frontend-neutral Rust
3. add framework-independent tests
4. expose it through the stable frontend/application API
5. integrate that API into GPUI presentation state
6. add Flutter/FFI mapping only if a Flutter frontend needs it
```

## M0 — architecture foundation acceptance gate

Before the production GPUI foundation can be called complete:

- [ ] GPUI dependencies exist only in frontend/app crates.
- [ ] Shared core crates compile without GPUI.
- [ ] Domain models contain no GPUI types.
- [ ] Catalog/storage/image-processing rules are testable without launching GPUI.
- [ ] Frontend-facing commands/DTOs/events are framework-neutral.
- [ ] Long-running core work exposes runtime-neutral results/progress.
- [ ] Platform-specific functionality is behind adapters.
- [ ] A future Flutter/FFI frontend can use the same application API.
- [ ] CI includes a dependency-policy guard preventing GPUI from entering protected core crates.

## Migration queue

```text
CURRENT   M0 frontend-neutral Rust architecture foundation
NEXT      M1 production GPUI bootstrap + command/state shell
THEN      M2 read-only authoritative Workplace/catalog adapter
THEN      M3 real Grid/Filmstrip catalog browsing
THEN      M4 import/catalog mutations
THEN      M5 Develop controls around existing Rust engine
THEN      M6 desktop export/settings/polish
THEN      M7 retire Flutter desktop only after parity/validation gates
OPTIONAL  future Flutter frontend through FFI using the same Rust core
```

The migration remains incremental. Existing Flutter production paths should remain buildable until corresponding GPUI behavior has been validated and authoritative storage migration is explicitly approved.

## Persistence boundary

Production Flutter currently owns durable Workplaces persistence through repositories/adapters and Hive. The GPUI experiment currently proves only the native repository boundary.

Production storage migration is a separate architectural milestone.

Requirements:

- exactly one authoritative durable catalog format;
- no GPUI-specific persistence semantics;
- no direct GPUI-to-Hive coupling;
- storage implementation must remain usable from the frontend-neutral Rust application layer;
- future Rust-native Dxtr_Box integration is compatible with this direction but must be evaluated as a storage milestone rather than smuggled into the UI migration.

## Product responsibility

Dextryx Images owns Workplaces, catalog identity, import/storage organization, thumbnail/preview browsing, Grid/Filmstrip selection, missing/relink workflows, catalog metadata, large-library UX and future external-edit orchestration.

PixelCraft / Dextryx Pixels remains processing authority for its own product roadmap. Do not duplicate that roadmap here.

## W4 physical validation track

W4 implementation/code gates are complete, but the real desktop D1-D8 evidence remains separate and must not be claimed as passed without physical validation.

Reference: `docs/W4_DESKTOP_VALIDATION.md`.

This track must not block defining the new frontend-neutral architecture, but any eventual removal of the Flutter desktop path must preserve or revalidate the same catalog/storage safety behavior.

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
DONE      define mandatory frontend-neutral core dependency contract
CURRENT   extract/promote reusable catalog/application contracts out of GPUI-owned code
NEXT      establish production Rust workspace/crate boundaries
NEXT      add architecture dependency guard in CI
NEXT      build GPUI app shell only on top of the stable frontend/application API
PARALLEL  W4 physical D1-D8 desktop evidence remains outstanding
```
