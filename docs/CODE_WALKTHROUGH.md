# Nixin Studio V8 — Code Walkthrough

This walkthrough documents the Flutter-side workspace foundation implemented in `feature/studio-workspace-redesign` for UI-01 through UI-08.

## 1. Startup flow

`lib/main.dart` is now bootstrap-only.

Startup sequence:

```text
WidgetsFlutterBinding.ensureInitialized()
  → EasyLocalization.ensureInitialized()
  → Hive.initFlutter()
  → Hive.openBox("studio_settings")
  → ProviderScope
  → EasyLocalization
  → NixinApp
```

This keeps initialization concerns out of the editor page and ensures Riverpod/Hive/localization are ready before studio providers are created.

## 2. App root

`lib/app/nixin_app.dart` owns the application shell:

- `MaterialApp`
- dark studio theme
- localization delegates
- supported locales
- current locale
- `StudioPage` as the workspace root

The app root does not know how RAW development or FFI works.

## 3. Theme and responsive tokens

`lib/app/theme/studio_theme.dart` centralizes:

- neutral workspace palette
- panel/surface/divider colors
- typography density
- spacing and radius scales
- module/status bar dimensions
- global compact Material density

Responsive composition thresholds and Flex ratios live with the studio state/layout model rather than being scattered through widgets.

## 4. Native engine boundary

### `lib/engine/engine_image.dart`

`EngineImage` is a simple result model:

```text
RGBA bytes
width
height
```

It has no Flutter widget responsibility.

### `lib/engine/raw_engine.dart`

`StudioEngine` defines the operations the Flutter studio is allowed to call:

```text
checkEngine
version
lastError
develop
subjectMask
skyMask
applyLut
exportJpeg
```

`RawEngine` is the concrete FFI implementation.

The important boundary is:

```text
StudioController → StudioEngine
```

rather than:

```text
Widget → DynamicLibrary / C functions
```

This makes UI tests independent of the native library.

## 5. FFI memory ownership

`RawEngine` preserves the original memory ownership rules:

```text
Dart UTF-8 input
  → allocated with calloc
  → passed to Rust
  → freed by Dart

Rust string output
  → CString::into_raw
  → converted to Dart String
  → freed with free_string_rust

Rust ImageBuffer
  → read width/height/len/data
  → copy RGBA bytes into Dart-owned Uint8List
  → free_image_buffer
```

The Dart side validates:

```text
len == width * height * 4
```

before accepting a returned RGBA buffer.

## 6. Studio state

`lib/studio/studio_state.dart` defines immutable `StudioState`.

Important fields:

```text
engineReady
engineVersion
rawPath
previewPng
imageWidth
imageHeight
previewStatus
errorMessage
statusMessage
exportQuality
activeModule
leftPanelVisible
rightPanelVisible
```

`PreviewStatus` has four explicit states:

```text
empty
processing
ready
error
```

This prevents widgets from inferring processing state from unrelated fields.

`copyWith(clearPreview: true)` clears preview bytes and dimensions when another RAW file becomes active.

## 7. Ratio-based layout model

The editor chooses its composition using:

```dart
viewportRatio = width / height;
```

`layoutModeForRatio()` returns:

```text
wide
medium
compact
```

Current ratio tokens:

```text
wideMinAspect   = 1.65
mediumMinAspect = 1.15
```

### Wide

```text
left : center : right
18   : 60     : 22
```

All three workspace regions can be present.

### Medium

```text
center : right
70     : 30
```

The permanent left context panel is removed so the preview keeps useful visual area. RAW import remains available elsewhere in the chrome.

### Compact

The preview becomes the primary surface and tool controls are presented through an overlay sheet.

This avoids tying device behavior to fixed pixel widths.

## 8. Riverpod controller

`lib/studio/studio_controller.dart` owns editor actions through `StudioController`, exposed by:

```dart
studioControllerProvider
```

Widgets watch immutable state:

```dart
ref.watch(studioControllerProvider)
```

and invoke behavior through:

```dart
ref.read(studioControllerProvider.notifier)
```

The controller performs these responsibilities:

- initialize engine readiness/version
- select RAW files
- clear stale preview when RAW selection changes
- run develop/mask operations
- select and apply LUT files
- export JPEG files
- normalize native errors into `StudioState`
- switch modules
- toggle panel visibility
- clamp and store export quality

## 9. Settings abstraction and Hive

Production persistence uses Hive but the controller does not depend directly on the full Hive `Box` API.

The boundary is:

```text
StudioSettingsStore
  ↑
HiveStudioSettingsStore
```

Production provider flow:

```text
studioSettingsBoxProvider
  → studioSettingsStoreProvider
  → StudioController
```

Stored values:

```text
activeModule
leftPanelVisible
rightPanelVisible
exportQuality
```

Not persisted:

```text
RAW file path
preview PNG
RGBA buffers
processing state
errors
```

The abstraction also lets unit tests use a small in-memory fake store.

## 10. Studio page composition

`lib/studio/studio_page.dart` is responsible for composing regions, not processing images.

High-level build flow:

```text
StudioPage
  → LayoutBuilder
  → calculate width / height ratio
  → layoutModeForRatio()
  → StudioModuleBar
  → selected workspace composition
  → StudioStatusBar
```

Wide, medium, and compact compositions are separate widgets so responsive behavior remains explicit and testable.

## 11. Workspace widgets

`lib/studio/studio_widgets.dart` contains reusable workspace primitives.

### `StudioModuleBar`

Owns:

- application identity
- Library / Develop / Export module actions
- primary RAW import access where required
- panel visibility controls where the composition supports them

### `StudioPanel`

Provides the shared panel surface and divider behavior.

### `StudioPanelSection`

Provides accordion-style collapsible sections with a reusable animation/interaction contract.

### `PreviewWorkspace`

Maps `PreviewStatus` to visible behavior:

```text
empty       → empty-state message
processing  → preview/loading overlay
ready       → Image.memory preview
error       → explicit error state
```

### `StudioStatusBar`

Shows contextual information such as:

- current filename
- image dimensions
- engine status/version
- operation status

### `ActionButton`

Normalizes compact full-width editor actions and disabled-state behavior.

## 12. Existing feature mapping

The refactor moved existing capabilities rather than inventing unsupported controls.

```text
Open RAW
  → module bar / Navigator context

Develop
  → Tools panel

Subject Mask
  → Tools panel

Sky Mask
  → Tools panel

Apply LUT
  → Presets context

JPEG Quality
  → Export settings

Export JPEG
  → Export action
```

All native signatures remain unchanged for UI-01 through UI-08.

## 13. Localization flow

Visible workspace strings use translation keys through `easy_localization`.

Resources:

```text
assets/translations/en.json
assets/translations/th.json
```

Typical usage:

```dart
'action.open_raw'.tr()
'panel.tools'.tr()
```

Do not embed new user-facing strings directly in studio widgets unless the string is intentionally non-localized technical output.

## 14. Test architecture

### `test/studio/studio_state_test.dart`

Covers pure state/layout behavior:

- wide/medium/compact ratio selection
- threshold boundaries
- filename derivation
- clearing preview bytes/dimensions
- clearing errors

### `test/studio/studio_controller_test.dart`

Uses:

```text
_MemorySettings
_FakeEngine
```

No native library is loaded.

Covers:

- restoring persisted settings
- persisting module/panel/export quality
- clamping export quality
- resetting old preview on new RAW selection
- develop action routing
- preview result publication
- engine error publication
- engine-unavailable initialization

### `test/studio/studio_widgets_test.dart`

Covers reusable widget behavior:

- panel section collapse/restore
- disabled action behavior

Run:

```bash
flutter test
```

## 15. Why the test seams matter

Before the extraction, editor behavior lived close to FFI and widgets, making tests likely to require a real native library.

The new structure creates deterministic seams:

```text
Widget tests
  → do not need FFI

Controller tests
  → fake StudioEngine
  → fake StudioSettingsStore

Native tests
  → remain in Rust / integration validation
```

This means visual/state refactors can be tested independently from Rust packaging and platform linking.

## 16. Validation order

Recommended local validation:

```bash
flutter pub get
flutter analyze
flutter test

cd rust
cargo check
cargo test
```

Then manually validate at least:

- launch
- locale initialization
- Hive preference restore
- RAW selection
- develop
- subject mask
- sky mask
- LUT application
- JPEG export
- wide ratio composition
- medium ratio composition
- compact ratio composition
- panel collapse/restore

## 17. Next UI milestone

The next batch should build on these boundaries instead of bypassing them:

```text
UI-09  compact editor control primitives
UI-10  filmstrip foundation
UI-11  zoom/comparison toolbar
UI-12  desktop keyboard shortcuts
UI-13  responsive refinement
UI-14  expanded widget/golden tests
UI-15  visual polish
```

New processing features should first be exposed through `StudioEngine`/controller contracts and only then connected to widgets.
