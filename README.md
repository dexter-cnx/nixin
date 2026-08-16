# Dextryx Images

**Dextryx Images** (`Dxtr Imgs`) is a Flutter + Rust desktop-first photo catalog and image workflow application.

The current development focus is **Workplaces and asset/catalog management**: importing images and RAW files, organizing them into durable logical catalogs, browsing/selecting assets, and preserving compatibility with the existing preview/Develop workflow.

Repository: `dexter-cnx/nixin`

Application/bundle ID:

```text
com.cnxdev.dextryx.images
```

## Current status

Completed:

- responsive Studio workspace UI-01 through UI-15
- Flutter ↔ Rust FFI image boundary
- embedded JPEG preview extraction for supported RAW containers
- raster preview support
- exposure / temperature / contrast processing already present in the Rust core
- heuristic Subject Mask and Sky Mask
- `.cube` LUT application
- JPEG export
- Riverpod application/controller boundaries
- Hive-backed Studio preferences
- English/Thai localization
- **W1 Workplace Core**
  - `Workplace` model
  - `AssetRecord` catalog model
  - repository interfaces
  - Hive-backed Workplace/Asset persistence
  - automatic `My workplace`
  - current Workplace restoration
  - create / switch / rename / delete behavior
  - last-Workplace invariant

Current milestone:

```text
W2 Import System
```

Next:

```text
W3 Workplace Browser + Filmstrip
W4 Desktop Catalog Hardening
```

See `docs/PROJECT_HANDOFF.md` for the canonical execution queue.

## Product scope

Dextryx Images owns image/catalog management:

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

A **Workplace** is a logical catalog/container. It is not required to map 1:1 to a physical folder.

The initial catalog is created automatically as:

```text
My workplace
```

## Product boundary with PixelCraft

Dextryx Images is the catalog/management side of the workflow.

PixelCraft / Dextryx Pixels owns photo-editing and image-processing semantics such as editor sessions, adjustments, transforms, GPU preview/render work, and processing authority.

Do not move PixelCraft roadmap or UX milestones into this repository. Stable reusable PixelCraft packages may be integrated later only through explicit module/package boundaries.

A future **Open/Edit in PixelCraft** workflow is a separate cross-product integration milestone.

## Current architecture

```text
Flutter UI
   │
   ├─ Workplaces
   │    ├─ WorkplaceController
   │    ├─ WorkplaceRepository
   │    ├─ AssetRepository
   │    └─ Hive persistence
   │
   └─ Studio compatibility layer
        ├─ StudioController
        ├─ StudioEngine
        └─ RawEngine / Dart FFI
                   │
                   ▼
               Rust core
```

Top-level Flutter structure:

```text
lib/
  main.dart
  app/
  engine/
  studio/
  workplaces/
```

`main.dart` initializes localization, Riverpod, and these Hive boxes:

```text
studio_settings
workplaces
assets
```

Widgets should not call native FFI or Hive directly. Processing and persistence flow through explicit controller/repository boundaries.

For code orientation, see `docs/CODE_WALKTHROUGH.md`.

## Workplaces

Current W1 implementation lives under:

```text
lib/workplaces/
  application/
    workplace_controller.dart
  data/hive/
    hive_workplace_repository.dart
    hive_asset_repository.dart
  domain/
    workplace.dart
    asset_record.dart
    repositories/
      workplace_repository.dart
      asset_repository.dart
```

Current behavior:

- first launch creates `My workplace`
- at least one Workplace always remains
- active Workplace survives restart
- Workplaces can be created, switched, renamed, and deleted
- deleting catalog state does not imply deleting original image files

## Current milestone — W2 Import System

The next implementation phase replaces the legacy single-file Open Image/Open RAW entry path with a catalog-aware import pipeline.

Planned W2 scope:

- Import command
- multi-select images/RAW files
- folder import
- recursive folder discovery
- supported-format filtering
- `ImportBatch`
- asynchronous progress
- cancellation
- duplicate detection
- linked/add storage mode
- desktop managed/copy storage mode
- managed destination preference
- safe partial-failure behavior
- persistence into the active Workplace

Detailed specification: `docs/WORKPLACES_HANDOFF.md`.

## RAW support today

Dextryx Images is **not yet a full sensor RAW developer**.

Supported RAW containers currently use an embedded JPEG preview when the scanner can locate one and the Rust `image` crate can decode it.

Picker/container coverage currently includes:

```text
ARW
CR2
CR3
NEF
DNG
RAF
ORF
```

Real sensor decode, demosaic/debayer, linear RAW processing, camera color matrices/profiles, and a complete RAW color pipeline are explicitly deferred while Workplaces/catalog work is being built.

## Existing processing compatibility

The current Rust/Studio path already provides:

- exposure
- simple temperature RGB scaling
- contrast
- heuristic Subject Mask
- heuristic Sky Mask
- `.cube` 3D LUT with trilinear interpolation
- JPEG export with quality control
- basic XMP sidecar API support

These existing capabilities are regression gates during W2–W4; this phase does not expand image-processing scope.

## Setup

Prerequisites:

- Flutter SDK
- Rust toolchain (`cargo`, `rustc`, `rustup`)
- Android SDK/NDK for Android native builds
- Xcode + command line tools for macOS/iOS builds

Bootstrap:

```bash
make setup
```

Useful targets:

```bash
make setup-common
make setup-android
make setup-apple
make bootstrap
```

## Validation

Full local gate:

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

For Workplaces changes, manually verify at minimum:

- application launch
- English/Thai initialization
- `My workplace` creation/restoration
- create/switch/rename/delete Workplace
- existing embedded RAW preview
- PNG/JPEG preview
- Develop
- Subject Mask
- Sky Mask
- LUT
- JPEG export

## Android

```bash
make android-arm64
make run-android DEVICE=<flutter-device-id>
```

Native output:

```text
android/app/src/main/jniLibs/arm64-v8a/libraw_engine.so
```

## macOS

```bash
make macos-native
make run-macos
```

Native output:

```text
macos/Native/libraw_engine.a
```

Apple platforms link the Rust `staticlib` and resolve C ABI symbols through `DynamicLibrary.process()`.

## iOS

```bash
make ios-native
make ios-build-nosign
flutter devices
make run-ios DEVICE=<flutter-device-id>
```

Generated native archives:

```text
ios/Native/device/libraw_engine.a
ios/Native/simulator/libraw_engine.a
```

The Makefile intentionally does not hard-code a personal device identifier.

## FFI ownership rules

- Dart `toNativeUtf8()` allocations are freed with `calloc.free()` in Dart after the Rust call.
- Rust `CString::into_raw()` results are freed only through `free_string_rust()`.
- Rust `ImageBuffer` results are copied into Dart-owned bytes before `free_image_buffer()`.
- Dart validates RGBA buffer length against `width * height * 4`.
- native image-returning FFI failures are exposed through the existing error boundary.

## Documentation

Current source-of-truth documents:

```text
docs/PROJECT_HANDOFF.md       current status and execution queue
docs/WORKPLACES_HANDOFF.md    detailed catalog/import design
docs/CODE_WALKTHROUGH.md      current code orientation
docs/DEXTRYX_IDENTITY.md      naming and identifiers
```

Historical milestone documents such as `docs/STUDIO_WORKSPACE_HANDOFF.md` remain useful for implementation history, but they are not the current roadmap.

## Roadmap

```text
DONE     W1 Workplace Core
CURRENT  W2 Import System
NEXT     W3 Workplace Browser + Filmstrip
THEN     W4 Desktop Catalog Hardening
FUTURE   PixelCraft external-editor contract
```

During W2–W4, do not start real RAW demosaic/debayer work and do not mix unrelated PixelCraft milestones into the Dextryx Images roadmap.
