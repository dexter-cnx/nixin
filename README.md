# Dextryx Images

**Dextryx Images** (`Dxtr Imgs`) is a Flutter + Rust desktop-first photo catalog and image workflow application.

Repository: `dexter-cnx/nixin`

Application/bundle ID:

```text
com.cnxdev.dextryx.images
```

## Current direction

The active product phase is **Workplaces and asset/catalog management**. The goal is to build a durable catalog around the existing Studio/preview pipeline before any new RAW-processing work.

The roadmap is:

```text
DONE     W1 Workplace Core foundation
CURRENT  W2 Import System + live application wiring
NEXT     W3 Workplace Browser + Filmstrip
THEN     W4 Desktop Catalog Hardening
FUTURE   PixelCraft external-editor contract
```

See `docs/PROJECT_HANDOFF.md` for the canonical execution queue and `docs/WORKPLACES_HANDOFF.md` for the detailed catalog/import design.

## What is implemented today

Existing Studio/Rust capabilities remain available:

- responsive Studio workspace UI-01 through UI-15
- Flutter ↔ Rust FFI image boundary
- embedded JPEG preview extraction for supported RAW containers
- raster preview support
- exposure / temperature / contrast processing
- heuristic Subject Mask and Sky Mask
- `.cube` LUT application
- JPEG export
- Riverpod Studio controller/state boundaries
- Hive-backed Studio preferences
- English/Thai localization

W1 added the **Workplace Core foundation** under `lib/workplaces/`:

- `Workplace` domain model
- `AssetRecord` catalog model
- `WorkplaceRepository` and `AssetRepository`
- Hive-backed Workplace/Asset persistence
- `WorkplaceController` and `WorkplaceState`
- controller logic for default `My workplace`
- current Workplace persistence/restoration logic
- create / switch / rename / delete commands
- invariant that at least one Workplace remains
- catalog-only deletion semantics

### Important current wiring state

W1's Workplace foundation is implemented and tested, but it is **not yet wired into the live application UI**.

`NixinApp` still opens `StudioPage`, and the live Studio tree does not yet watch `workplaceControllerProvider`. Because Riverpod providers are lazy, `WorkplaceController.initialize()` is not invoked merely by opening the app today.

Therefore these are currently **controller/domain capabilities**, not yet end-user behavior:

- automatic creation of `My workplace` on a real fresh app launch
- visible Workplace switching/creation/rename/delete UI
- active Workplace driving the current Studio selection

Closing this application-wiring gap is the first part of W2.

## Product responsibility

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

A **Workplace** is a logical catalog/container, not a physical folder alias.

PixelCraft / Dextryx Pixels owns photo-editing and image-processing semantics. Do not copy PixelCraft UX or processing milestones into this repository. Future Open/Edit in PixelCraft integration is a separate cross-product contract.

## Current architecture

```text
main.dart
  ├─ localization
  ├─ Hive init
  │    ├─ studio_settings
  │    ├─ workplaces
  │    └─ assets
  └─ ProviderScope
       └─ NixinApp
            └─ StudioPage        ← current live root

lib/workplaces/
  ├─ domain/
  ├─ data/hive/
  └─ application/
       └─ WorkplaceController    ← implemented, not yet consumed by live UI
```

The processing path remains:

```text
Studio UI
  → StudioController
    → StudioEngine
      → RawEngine / Dart FFI
        → Rust core
```

Widgets should not call native FFI or Hive directly.

## W2 — Import System + application wiring

W2 starts by making Workplace state part of the live application, then adds the durable import pipeline defined in `docs/WORKPLACES_HANDOFF.md`.

Planned scope:

- wire `workplaceControllerProvider` into the live app/workspace
- ensure a real fresh launch initializes `My workplace`
- expose current Workplace context in application UI/state
- preserve current Studio behavior while catalog state becomes authoritative
- Import command replacing the legacy single-file entry path
- multi-select image/RAW import
- folder import and recursive discovery
- supported-format filtering
- `ImportBatch`
- asynchronous progress and cancellation
- duplicate detection
- linked/add mode
- desktop managed/copy mode
- managed destination preference
- safe partial-failure behavior
- imported assets persisted to the active Workplace

Acceptance includes proving the Workplace foundation is reachable through the real application, not only through controller tests.

## W3 — Workplace Browser + Filmstrip

Planned scope:

- Workplace asset grid
- thumbnail/preview provider boundary
- thumbnail cache foundation
- lazy/virtualized browser
- one ordered asset source of truth
- one selected-asset source of truth
- Grid ↔ Filmstrip synchronization
- imported assets automatically reflected in Filmstrip
- basic sorting and missing-asset indicator foundation

## W4 — Desktop Catalog Hardening

Planned scope:

- missing-file detection
- Locate Missing File / Folder
- disconnected external-storage behavior
- managed-storage recovery
- import/copy failure recovery
- catalog-only removal semantics
- large-catalog profiling and performance hardening

Catalog removal and physical deletion must remain separate operations.

## RAW support today

Dextryx Images is **not yet a full sensor RAW developer**.

Supported RAW containers currently rely on embedded JPEG previews when available. Current picker/container coverage includes:

```text
ARW
CR2
CR3
NEF
DNG
RAF
ORF
```

Real sensor decode, demosaic/debayer, linear RAW processing, camera color matrices/profiles, and a complete RAW color pipeline are explicitly deferred during W2–W4.

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

Validation:

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

## Platform native builds

Android:

```bash
make android-arm64
make run-android DEVICE=<flutter-device-id>
```

macOS:

```bash
make macos-native
make run-macos
```

iOS:

```bash
make ios-native
make ios-build-nosign
make run-ios DEVICE=<flutter-device-id>
```

The Makefile does not hard-code a personal device identifier.

## Documentation

```text
docs/PROJECT_HANDOFF.md       canonical current status and execution queue
docs/WORKPLACES_HANDOFF.md    detailed Workplaces/import/catalog specification
docs/CODE_WALKTHROUGH.md      current code orientation and wiring state
docs/DEXTRYX_IDENTITY.md      naming and identifiers
docs/STUDIO_WORKSPACE_HANDOFF.md  completed Studio milestone history
```

During W2–W4, do not start real RAW demosaic/debayer work and do not mix unrelated PixelCraft milestones into the Dextryx Images roadmap.
