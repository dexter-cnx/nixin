# Nixin Studio V8

Nixin Studio V8 is a Flutter + Rust photo-editor foundation with a responsive professional studio workspace. The current image path scans camera RAW container bytes for an **embedded JPEG preview**, returns a real RGBA image buffer over C FFI, and exposes develop, mask, LUT, and JPEG export workflows through a Riverpod-driven Flutter UI.

## Current workspace milestone

Branch: `feature/studio-workspace-redesign`

Implemented scope (`UI-01` → `UI-08`):

- extracted Dart FFI/native image handling from `lib/main.dart`
- introduced `StudioEngine` / `RawEngine` boundary
- introduced Riverpod `StudioController` + immutable `StudioState`
- added Hive-backed workspace preferences
- added `easy_localization` with English and Thai resources
- added centralized studio colors, spacing, density, metrics, and ratio tokens
- added module bar, status bar, left context panel, preview workspace, right tool panel
- added collapsible panel sections
- moved existing RAW/develop/mask/LUT/export actions into contextual workspace regions
- added ratio-based responsive composition
- added unit/widget test suites for state, controller, persistence, fake engine behavior, panel collapse, and ratio selection

Detailed implementation notes:

- `docs/STUDIO_WORKSPACE_HANDOFF.md`
- `docs/CODE_WALKTHROUGH.md`

## What it is

- Working Rust embedded-preview processor.
- Dart FFI bridge with explicit allocator ownership.
- Real Flutter image display through RGBA → PNG conversion.
- Riverpod state/controller boundary between widgets and native engine calls.
- Hive persistence for lightweight workspace preferences.
- English/Thai localization through `easy_localization`.
- Responsive studio workspace driven primarily by viewport aspect ratio.
- Exposure, simple temperature RGB scaling, and contrast in the Rust core.
- Heuristic subject and sky masks.
- `.cube` 3D LUT with trilinear interpolation.
- JPEG export with quality 1–100.
- Basic XMP sidecar generation through the Rust core API.

## What it is not

This is **not** a full RAW developer yet. It does not currently debayer sensor mosaics, perform a complete camera color pipeline, lens correction, highlight recovery, GPU processing, real SAM/ONNX inference, USB/PTP tethered shooting, or production batch processing.

The UI intentionally avoids presenting unsupported adjustment controls as functional features.

## Flutter architecture

```text
main.dart
  │
  ├─ EasyLocalization.ensureInitialized()
  ├─ Hive.initFlutter()
  ├─ Hive.openBox("studio_settings")
  └─ ProviderScope
       │
       ▼
NixinApp
  │
  ├─ StudioTheme
  ├─ easy_localization delegates / locale
  └─ StudioPage
       │
       ├─ studioControllerProvider
       │    ├─ StudioState
       │    ├─ StudioSettingsStore → HiveStudioSettingsStore
       │    └─ StudioEngine → RawEngine → Dart FFI → Rust
       │
       ├─ StudioModuleBar
       ├─ ratio-based workspace composition
       │    ├─ left context panel
       │    ├─ PreviewWorkspace
       │    └─ right tools/export panel
       └─ StudioStatusBar
```

Main ownership boundaries:

```text
lib/
  main.dart                         bootstrap only
  app/
    nixin_app.dart                  app/localization/theme root
    theme/studio_theme.dart         design + ratio tokens
  engine/
    engine_image.dart               image result model
    raw_engine.dart                 FFI and StudioEngine implementation
  studio/
    studio_state.dart               immutable studio state + ratio layout rules
    studio_controller.dart          Riverpod actions + settings persistence
    studio_page.dart                workspace composition
    studio_widgets.dart             reusable panels/preview/status/actions
```

Widgets do not call native FFI directly. Processing flows through:

```text
Widget
  → StudioController
    → StudioEngine
      → RawEngine
        → Rust C ABI
```

## State management

State management uses `flutter_riverpod`.

`StudioState` currently owns:

- engine readiness and version
- selected RAW path
- preview PNG bytes and image dimensions
- preview status: `empty`, `processing`, `ready`, `error`
- current status/error
- active workspace module
- left/right panel visibility
- JPEG export quality

The controller is dependency-injectable, so tests can use a fake engine and an in-memory settings store without loading native libraries.

## Hive persistence

Hive persists only lightweight workspace preferences in the `studio_settings` box:

```text
activeModule
leftPanelVisible
rightPanelVisible
exportQuality
```

RAW paths, preview bytes, and image buffers remain runtime state.

## Localization

Localization uses `easy_localization`.

Resources:

```text
assets/translations/en.json
assets/translations/th.json
```

Supported locales:

```text
en
th
```

New visible UI strings should be added as translation keys rather than hard-coded in widgets.

## Ratio-based responsive behavior

Responsive mode is selected from the available workspace aspect ratio:

```dart
viewportRatio = availableWidth / availableHeight;
```

Current ratio tokens:

```text
wide      ratio >= 1.65
medium    ratio >= 1.15 and < 1.65
compact   ratio < 1.15
```

The layout does not use fixed pixel widths as its primary mode switch.

Wide composition:

```text
left : preview : right
18   : 60      : 22
```

Medium composition:

```text
preview : right
70      : 30
```

Compact composition keeps the preview dominant and opens tools in an overlay sheet rather than squeezing a desktop three-column workspace into a narrow view.

## Existing action mapping

```text
Open RAW       → module bar / left Navigator context
Develop        → right Tools section
Subject Mask   → right Tools section
Sky Mask       → right Tools section
Apply LUT      → left Presets section
Export JPEG    → right Export section
JPEG Quality   → right Export settings
```

All of these continue to use the existing Rust API contract.

## Test suites

Run all Flutter tests:

```bash
flutter test
```

Current studio suites:

```text
test/studio/studio_state_test.dart
  - ratio mode selection
  - filename derivation
  - preview/error clearing semantics

test/studio/studio_controller_test.dart
  - persisted preference restore
  - module/panel/export-quality persistence
  - export quality clamping
  - RAW selection resets old preview state
  - fake-engine develop flow
  - native error propagation
  - engine-unavailable behavior

test/studio/studio_widgets_test.dart
  - collapsible panel section behavior
  - disabled action behavior
```

The controller tests use `StudioSettingsStore` and a fake `StudioEngine`, so they do not require the Rust dynamic/static library to load.

## Supported picker extensions

ARW, CR2, CR3, NEF, DNG, RAF, ORF.

Support currently depends on the RAW container containing an embedded JPEG preview that the scanner can locate and the Rust `image` crate can decode.

## Limitations

1. Uses an embedded JPEG preview, not RAW sensor debayering.
2. Some RAW containers may use preview layouts that the JPEG marker scanner does not locate reliably.
3. Exposure operates on 8-bit preview pixels, so highlight latitude is limited.
4. Temperature uses simple red/blue scaling rather than chromatic adaptation.
5. Tint is not implemented.
6. Shadows/highlights/whites/blacks are not implemented.
7. Subject mask is heuristic segmentation, not AI.
8. Sky mask can false-positive on bright or blue non-sky regions.
9. `.cube` `DOMAIN_MIN`/`DOMAIN_MAX` are parsed but sampling currently assumes normalized 0–1 input.
10. No GPU path, USB/PTP tethering, real batch queue, color-managed monitor pipeline, or embedded XMP-in-JPEG writer yet.
11. Filmstrip, advanced zoom/comparison, keyboard workflow, and advanced adjustment panels are follow-up milestones.

## Project setup

Prerequisites:

- Flutter SDK
- Rust toolchain (`cargo`, `rustc`, `rustup`)
- Android SDK/NDK for Android native builds
- Xcode + command line tools for macOS/iOS builds

Bootstrap:

```bash
make setup
```

Useful setup targets:

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
cd rust
cargo check
cargo test
cd ..
flutter analyze
flutter test
```

Also manually validate:

- application launch
- English/Thai initialization
- Hive preference restore
- RAW selection
- develop
- subject mask
- sky mask
- LUT application
- JPEG export
- wide / medium / compact ratio compositions
- side-panel collapse/restore

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

- Dart `toNativeUtf8()` → `calloc.free()` in Dart after the Rust call.
- Rust `CString::into_raw()` → `free_string_rust()` only.
- Rust `Box<ImageBuffer>` → Dart copies bytes → `free_image_buffer()`.
- Buffer getters are null-safe.
- Dart validates `len == width * height * 4` before copying.
- Rust image-returning FFI boundaries report failures through `LAST_ERROR`.

## `check_engine()`

`check_engine()` confirms the library is loaded and its basic internal state is usable. It does **not** validate RAW decoding quality, packaging, filesystem permissions, AI, or GPU support.

## Watched folder import

The Rust core includes watched-folder semantics through `TetheredWatcher::check_new_files(known)`, but this is **not** USB/PTP tethered shooting.
