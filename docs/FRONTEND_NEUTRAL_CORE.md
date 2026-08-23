# Dextryx Images — Frontend-Neutral Rust Core Contract

Date: 2026-08-24

Branch: `agent/gpui-desktop-spike`

## Decision

Dextryx Images will proceed with **GPUI as the preferred native desktop frontend**, while the authoritative Rust core remains **frontend-neutral**.

GPUI is a presentation/application-shell dependency. It must never become a dependency of domain, storage, catalog, import, thumbnail, metadata, or image-processing core crates.

This is a permanent architecture rule intended to keep a future Flutter frontend viable without rewriting the product core.

## M0 implementation status

The first code boundary is now real rather than documentation-only:

```text
crates/dextryx-core
  ├─ Cargo.toml          no GPUI/Flutter/FFI dependencies
  ├─ src/lib.rs          catalog domain + CatalogRepository contract
  └─ tests/              framework-independent catalog semantics

experiments/gpui-desktop
  └─ depends on dextryx-core through a normal path dependency
```

The former GPUI-owned `src/catalog.rs` has been removed. The GPUI boundary test imports `dextryx_core` directly, while the full catalog semantic tests now execute inside the shared core crate.

Current extracted behavior includes stable asset/workplace identity, linked vs managed effective paths, filtering, relink semantics, active Workplace state, and catalog-only removal.

`SyntheticCatalogRepository` remains a test adapter only. Production persistence is still deferred and must not be introduced as part of this extraction.

### Temporary lockfile note

Adding the new path crate requires regenerating `experiments/gpui-desktop/Cargo.lock` with Cargo. Until that generated lockfile is committed, the S4 workflow intentionally runs the affected Cargo commands without `--locked`. Do not hand-edit or guess Cargo's resolved lockfile. After regeneration, restore strict `--locked` validation.

## Target dependency direction

```text
GPUI desktop frontend ───────┐
                            │
Flutter frontend -> FFI ────┼──> frontend/application API ──> Rust core
                            │                               ├─ catalog/workplaces
CLI/tests/automation ───────┘                               ├─ import orchestration
                                                            ├─ storage contracts
                                                            ├─ thumbnail/cache policy
                                                            ├─ metadata
                                                            └─ image engine
```

Dependencies may point inward toward the core. Core crates must not point outward toward GPUI, Flutter, Dart, or FFI bindings.

## Crate boundary target

The current GPUI code is still an experiment. Production migration should converge toward responsibilities equivalent to:

```text
crates/
  dextryx_core/          pure domain + application rules
  dextryx_storage/       persistence contracts/adapters
  dextryx_image_engine/  RAW/raster processing authority
  dextryx_thumbnail/     thumbnail/cache scheduling and policy
  dextryx_platform/      filesystem/OS adapter boundaries
  dextryx_frontend_api/  stable frontend-facing commands/DTOs/events
  dextryx_ffi/           optional Flutter bridge only

apps/
  desktop_gpui/          GPUI state, windows, commands, widgets, shortcuts
  flutter/               optional future Flutter frontend
```

Exact crate names may change. The dependency direction must not.

## Hard rules

### Core must not contain GPUI types

Forbidden in core/domain/application code:

```text
gpui::Entity<T>
gpui::Context<_>
gpui::Window
gpui::Task<_>
GPUI actions/subscriptions/render elements
```

Domain models must remain ordinary Rust data structures and enums.

### GPUI owns presentation state only

GPUI may own:

- selected tile / selected asset presentation state;
- panel visibility;
- focus and shortcuts;
- window state;
- view-specific loading/progress state;
- GPUI entities/subscriptions;
- conversion of neutral core events into UI updates.

GPUI must not become the authority for:

- catalog identity;
- linked vs managed storage semantics;
- relink rules;
- import duplicate prevention;
- durable persistence;
- cache validity policy;
- image-processing rules.

### Stable frontend API

Frontends should call semantic application operations rather than individual storage implementations or internal object graphs.

Representative operations:

```text
list_workplaces()
list_assets(workplace_id, query)
open_asset(asset_id)
import_assets(request)
relink_asset(asset_id, replacement)
remove_from_catalog(asset_id)
request_thumbnail(asset_id, spec)
develop_preview(asset_id, adjustments)
```

The production API may use traits, concrete application services, message/command types, or a combination. It must remain independent from GPUI.

### Runtime-neutral async/event model

Long-running work such as import, thumbnail generation and RAW decode must not expose GPUI task types from the core.

The core should publish neutral progress/results/events. The GPUI adapter may translate them into GPUI tasks/entities; a future Flutter bridge may translate them into Dart Futures/Streams.

Representative event contract:

```text
ImportEvent
  Started { total }
  Progress { completed, total }
  AssetImported { asset_id }
  Failed { source, error }
  Completed
```

### Flutter bridge boundary

A future Flutter implementation should use:

```text
Flutter
  -> Dart state/view-model layer
  -> generated/manual FFI bridge
  -> dextryx_frontend_api
  -> Rust core
```

Flutter must not call GPUI code, and the core must not be redesigned around Dart DTOs. The FFI layer is a translation boundary only.

Potential bridge technology such as `flutter_rust_bridge` is an implementation choice and is deliberately not a core dependency.

## Current GPUI spike rule

`experiments/gpui-desktop` may temporarily contain synthetic presentation data and GPUI-specific composition because it is an experiment, but any code promoted to production core must first cross the frontend-neutral boundary.

The catalog contract has now crossed that boundary into `crates/dextryx-core`.

Do not connect the GPUI spike directly to Hive and do not create a second durable catalog format.

## M0 architecture acceptance gate

Before calling the production GPUI foundation complete:

- [x] Initial shared core crate compiles independently by construction with no GPUI dependency declared.
- [x] Extracted catalog domain models contain no GPUI types.
- [x] Extracted catalog/storage semantics are covered by framework-independent tests.
- [x] GPUI boundary tests consume the shared crate instead of source-path inclusion.
- [ ] Move remaining application/domain behavior out of GPUI-owned code where applicable.
- [ ] Define frontend-facing command/DTO/event boundary.
- [ ] Define runtime-neutral progress/events for long-running operations.
- [ ] Put platform-specific filesystem/UI behavior behind adapters.
- [ ] Add a future Flutter/FFI entry point against the same application API.
- [ ] Add a dependency-graph CI guard that fails if protected core crates gain GPUI/Flutter/FFI dependencies.
- [ ] Regenerate GPUI `Cargo.lock`, commit it, and restore `--locked` S4 commands.

## CI guard direction

When the shared workspace matures, add an automated dependency-policy check. At minimum it should verify that protected core crates do not depend on `gpui`, `gpui_platform`, Flutter/Dart bindings, or the GPUI app crate.

A stronger guard should use `cargo metadata` to validate the transitive dependency graph rather than relying only on text search.

## Migration rule

Promote functionality from the GPUI experiment in this order:

```text
1. identify domain/application behavior
2. place that behavior in frontend-neutral Rust
3. add framework-independent tests
4. expose it through the frontend/application API
5. integrate it into GPUI presentation state
6. add FFI mapping only when/if Flutter needs the operation
```

Do not port by copying business logic into GPUI widgets.

## Architectural definition of success

The desired product is:

```text
Rust Core + GPUI Desktop Frontend
```

not:

```text
GPUI application with embedded product/domain logic
```

The first architecture keeps GPUI optimized for the current desktop product while preserving a low-cost path to Flutter mobile/desktop or another frontend later.
