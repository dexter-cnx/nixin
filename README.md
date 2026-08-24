# Dextryx Images

**Dextryx Images** (`Dxtr Imgs`) is a desktop-first photo catalog and image workflow application built around a shared Rust core.

Repository: `dexter-cnx/nixin`

Application/bundle ID:

```text
com.cnxdev.dextryx.images
```

## Current direction

The preferred desktop direction is now **Rust + GPUI**, validated through the native desktop spike. Flutter remains an existing frontend and a supported future frontend option, but product/domain logic must not become coupled to GPUI.

The architectural target is:

```text
Rust core
  ├─ GPUI desktop frontend
  ├─ optional Flutter frontend through FFI
  ├─ CLI / tests / automation
  └─ one authoritative storage/catalog implementation
```

The current GPUI experiment lives on `agent/gpui-desktop-spike`. GPUI is treated as presentation/application-shell technology, not as the owner of catalog, storage, import, thumbnail, metadata, or image-processing semantics.

See `docs/FRONTEND_NEUTRAL_CORE.md` for the mandatory dependency rules and migration gate.

## Product responsibility

Dextryx Images owns:

```text
Workplaces
asset catalog identity
import and folder discovery
linked vs managed storage
asset organization
thumbnail/preview browsing
grid / filmstrip selection
missing / relink workflows
catalog metadata
large-library UX
external-edit orchestration
```

PixelCraft / Dextryx Pixels remains processing authority for its product roadmap. Do not duplicate that roadmap here.

## Architecture

Target dependency direction:

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

Core dependencies must never point back to GPUI, Flutter, Dart, or FFI bindings.

Current production Flutter persistence still exists through its Workplaces repositories/Hive adapters. Production persistence migration is intentionally deferred until one authoritative Rust-side storage/catalog architecture is selected.

## GPUI desktop spike status

The spike has demonstrated on macOS:

- native GPUI window/rendering;
- direct Rust-to-Rust image-engine use;
- image viewport interaction;
- 5,000-asset Filmstrip-style virtualization with bounded thumbnail work;
- framework-neutral catalog repository semantics;
- linked/managed path behavior, relink and catalog-only removal contracts.

The spike must not connect directly to Hive or create a second durable catalog format.

## Frontend-neutral core rule

Any functionality promoted from the experiment must follow this order:

```text
1. identify domain/application behavior
2. place it in frontend-neutral Rust
3. add framework-independent tests
4. expose it through a stable application/frontend API
5. integrate that API into GPUI presentation state
6. add Flutter/FFI mapping only if a Flutter frontend needs it
```

GPUI-specific types such as `gpui::Entity`, `Context`, `Window`, `Task`, actions and render elements are forbidden in shared core crates.

A future Flutter bridge should translate neutral Rust commands/DTOs/events into Dart Futures/Streams without redesigning the Rust core around Dart.

## Import storage modes

**Linked / Add** catalogs the original where it already lives.

**Managed / Copy** copies the original under a managed root while keeping source and managed paths distinct.

Catalog removal and physical file deletion are separate concepts. Deleting a Workplace/catalog record must not silently delete original files.

## RAW support today

Dextryx Images is **not yet a full sensor RAW developer**. Supported RAW containers currently use embedded JPEG previews when available.

Current RAW extensions:

```text
ARW CR2 CR3 NEF DNG RAF ORF
```

Common raster formats are also accepted by the current import/preview path.

Real sensor decode, demosaic/debayer, linear RAW processing and camera color pipeline work remain explicitly deferred while the desktop/core architecture is being stabilized.

## Existing processing compatibility

The current Rust/Studio path already provides:

- embedded RAW/raster preview path
- exposure / temperature / contrast
- heuristic Subject Mask
- heuristic Sky Mask
- `.cube` LUT application
- JPEG export

These remain regression gates rather than the current migration focus.

## Setup

Existing Flutter/Rust production prerequisites remain unchanged. The GPUI experiment additionally requires a Rust toolchain and native desktop toolchain suitable for the pinned GPUI revision.

Production validation:

```bash
make validate
```

GPUI spike validation is documented in:

```text
docs/GPUI_DESKTOP_SPIKE.md
docs/GPUI_ARCHITECTURE_REVIEW.md
docs/GPUI_S4_COMPATIBILITY.md
```

## Documentation

```text
docs/PROJECT_HANDOFF.md             canonical production status / queue
docs/FRONTEND_NEUTRAL_CORE.md       mandatory Rust-core/frontend dependency contract
docs/GPUI_ARCHITECTURE_REVIEW.md    GPUI migration decision and evidence
docs/GPUI_DESKTOP_SPIKE.md          desktop spike implementation / validation
docs/GPUI_S4_COMPATIBILITY.md       packaging/platform compatibility gate
docs/CODE_WALKTHROUGH.md            current production code ownership/data flow
docs/DEXTRYX_IDENTITY.md            naming and identifiers
```
