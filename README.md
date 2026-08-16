# Dextryx Images

**Dextryx Images** (`Dxtr Imgs`) is a Flutter + Rust desktop-first photo catalog and image workflow application.

Repository: `dexter-cnx/nixin`

Application/bundle ID:

```text
com.cnxdev.dextryx.images
```

## Current direction

The active product phase is **Workplaces and asset/catalog management**. Existing Studio/preview processing remains a compatibility layer while catalog/import becomes the application authority.

Roadmap:

```text
DONE     W1 Workplace Core foundation
CURRENT  W2 Import System + live Workplace wiring
NEXT     W3 Workplace Browser + Filmstrip
THEN     W4 Desktop Catalog Hardening
FUTURE   PixelCraft external-editor contract
```

## Current W2 branch

`feature/workplaces-import` wires the W1 Workplace foundation into the live Studio UI and introduces the first durable import pipeline.

Implemented in the branch:

- real live consumption of `workplaceControllerProvider`
- automatic `My workplace` initialization when the Studio UI mounts on a fresh catalog
- Workplace switch/create/rename/delete controls
- primary multi-select Import
- folder import with recursive discovery by default
- current-folder-only folder import option
- supported RAW/raster filtering
- persisted `ImportBatch`
- import progress/cancellation state
- baseline duplicate prevention by normalized source path within the active Workplace
- linked/add mode
- desktop managed/copy mode
- remembered storage mode and managed destination
- safe per-file failure accounting
- imported asset persistence to the active Workplace
- latest imported asset handed to the existing Studio preview/Develop path

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

PixelCraft / Dextryx Pixels owns editing/image-processing semantics. Do not copy PixelCraft UX or processing milestones into this repository.

## Architecture

```text
Flutter UI
  ├─ Workplaces / Import
  │    ├─ WorkplaceController
  │    ├─ ImportController
  │    ├─ WorkplaceRepository
  │    ├─ AssetRepository
  │    ├─ ImportRepository
  │    └─ Hive persistence
  │
  └─ Studio compatibility
       ├─ StudioController
       ├─ StudioEngine
       └─ RawEngine / Dart FFI
                ↓
             Rust core
```

Hive boxes:

```text
studio_settings
workplaces
assets
import_batches
```

## Import storage modes

**Linked / Add** catalogs the original where it already lives.

**Managed / Copy** copies the original under a user-selected managed root using a stable asset-ID filename while keeping `sourcePath` and `managedPath` separate.

Catalog removal and physical file deletion are separate concepts. Deleting a Workplace/catalog record must not silently delete original files.

## RAW support today

Dextryx Images is **not yet a full sensor RAW developer**. Supported RAW containers currently use embedded JPEG previews when available.

Current RAW extensions:

```text
ARW CR2 CR3 NEF DNG RAF ORF
```

Common raster formats are also accepted by the current import/preview path.

Real sensor decode, demosaic/debayer, linear RAW processing and camera color pipeline work remain explicitly deferred during W2–W4.

## Existing processing compatibility

The current Rust/Studio path already provides:

- embedded RAW/raster preview path
- exposure / temperature / contrast
- heuristic Subject Mask
- heuristic Sky Mask
- `.cube` LUT application
- JPEG export

These are regression gates, not the current roadmap focus.

## Setup

Prerequisites:

- Flutter SDK
- Rust toolchain (`cargo`, `rustc`, `rustup`)
- Android SDK/NDK for Android native builds
- Xcode + command line tools for macOS/iOS builds

```bash
make setup
```

## Validation

```bash
make validate
```

Equivalent core commands:

```bash
flutter pub get
flutter analyze
flutter test

cd rust
cargo check
cargo test
```

For W2, manually verify multi-select import, recursive folder import, linked mode, managed mode, cancellation, Workplace persistence/CRUD, restart behavior, and existing RAW/raster preview + Develop/Mask/LUT/JPEG export.

## Documentation

```text
docs/PROJECT_HANDOFF.md       canonical current status/queue
docs/WORKPLACES_HANDOFF.md    detailed Workplaces/import design
docs/CODE_WALKTHROUGH.md      current code orientation
docs/DEXTRYX_IDENTITY.md      naming and identifiers
docs/W2_IMPORT_IMPLEMENTATION.md branch implementation note
```
