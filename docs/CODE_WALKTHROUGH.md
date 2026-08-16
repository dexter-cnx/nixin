# Dextryx Images — Code Walkthrough

This document is the current code orientation for `dexter-cnx/nixin` after the Studio workspace milestones and **W1 Workplace Core**. Historical implementation details belong in milestone-specific handoff documents; this file describes the structure developers should use now.

## 1. Application bootstrap

`lib/main.dart` is bootstrap-only.

Startup sequence:

```text
WidgetsFlutterBinding.ensureInitialized()
  → EasyLocalization.ensureInitialized()
  → Hive.initFlutter()
  → open Hive boxes
       ├─ studio_settings
       ├─ workplaces
       └─ assets
  → ProviderScope
  → EasyLocalization
  → NixinApp
```

The three Hive boxes currently separate lightweight studio preferences from Workplace and Asset catalog persistence.

## 2. Top-level ownership

Current Flutter structure:

```text
lib/
  main.dart
  app/
  engine/
  studio/
  workplaces/
```

Responsibilities:

```text
app/         application shell, theme, localization root
engine/      native image-processing boundary and FFI implementation
studio/      existing workspace, preview, Develop/Mask/LUT/Export compatibility
workplaces/  catalog domain, persistence, current Workplace state
```

The current roadmap expands `workplaces/`; it should not move new catalog behavior into leaf Studio widgets.

## 3. App root

`lib/app/nixin_app.dart` owns the Flutter application shell and localization/theme wiring.

The app layer should stay ignorant of FFI details and catalog persistence implementation. Those concerns belong behind `engine/` and `workplaces/` boundaries.

## 4. Native engine boundary

### `lib/engine/engine_image.dart`

`EngineImage` represents a native image result:

```text
RGBA bytes
width
height
```

### `lib/engine/raw_engine.dart`

`StudioEngine` is the Flutter-facing processing contract. `RawEngine` is the concrete FFI implementation.

The dependency direction remains:

```text
Studio UI
  → StudioController
    → StudioEngine
      → RawEngine
        → Rust C ABI
```

Widgets must not call `DynamicLibrary` or native functions directly.

The existing processing path currently supports embedded RAW previews/raster decoding plus the already-shipped adjustment, mask, LUT, and JPEG export behavior. Real RAW sensor development remains deferred.

## 5. FFI memory ownership

The native boundary preserves explicit allocator ownership:

```text
Dart UTF-8 input
  → calloc allocation
  → Rust call
  → Dart frees with calloc.free()

Rust string output
  → CString::into_raw()
  → Dart converts to String
  → free_string_rust()

Rust ImageBuffer
  → Dart reads width/height/len/data
  → Dart copies RGBA into Uint8List
  → free_image_buffer()
```

Dart validates:

```text
len == width * height * 4
```

before accepting an RGBA result.

## 6. Studio compatibility layer

`lib/studio/` contains the completed studio workspace foundation. It remains operational while Workplaces becomes the catalog authority.

Important responsibilities include:

- `StudioState` for preview/editor state
- `StudioController` for existing native actions
- responsive workspace composition
- module/status bars
- preview surface
- Develop, mask, LUT, and JPEG export interactions
- existing Filmstrip implementation to be evolved during W3

During W2–W4, avoid a broad Studio state-management rewrite. Use adapters where needed to migrate from legacy single-path selection toward catalog-selected assets.

## 7. Workplaces domain

`lib/workplaces/domain/` contains catalog concepts independent of Hive and widgets.

Current files:

```text
lib/workplaces/domain/
  workplace.dart
  asset_record.dart
  repositories/
    workplace_repository.dart
    asset_repository.dart
```

### `Workplace`

Represents a logical catalog/container. A Workplace is not a physical folder alias.

Current behavior expects:

- stable ID
- display name
- created/updated timestamps
- default marker

### `AssetRecord`

Represents catalog identity for an imported image/RAW asset.

The model keeps catalog metadata separate from the existing runtime Studio preview state. W2 should extend import behavior around this model rather than reverting to file-path-only application state.

## 8. Repository contracts

Domain repository interfaces are intentionally small and persistence-agnostic:

```text
WorkplaceRepository
AssetRepository
```

Dependency direction:

```text
Controller / application logic
  → repository interface
    → Hive implementation
```

Widgets must not read/write Hive directly.

This keeps a future catalog-store migration possible without rewriting UI/domain code.

## 9. Hive persistence

Current concrete implementations:

```text
lib/workplaces/data/hive/
  hive_workplace_repository.dart
  hive_asset_repository.dart
```

Current boxes:

```text
studio_settings
workplaces
assets
```

`studio_settings` also stores the current Workplace ID through the Workplace repository boundary.

The catalog database is authoritative for logical Workplace membership. Physical source paths and future managed-copy paths must remain storage metadata, not Workplace identity.

## 10. Workplace application state

`lib/workplaces/application/workplace_controller.dart` defines:

```text
WorkplaceState
WorkplaceController
workplaceControllerProvider
workplaceRepositoryProvider
assetRepositoryProvider
```

`WorkplaceState` currently owns:

```text
workplaces
currentWorkplaceId
loading
errorMessage
```

It exposes `currentWorkplace` as a derived lookup.

### Initialization

`WorkplaceController.initialize()`:

```text
load all Workplaces
  → if empty, create "My workplace"
  → restore current Workplace ID
  → if missing/invalid, choose first Workplace
  → persist repaired current ID
  → publish ready state
```

### Commands

Current controller commands:

```text
createWorkplace(name)
switchWorkplace(id)
renameWorkplace(id, name)
deleteWorkplace(id)
```

Important invariant:

```text
At least one Workplace must remain.
```

Deleting a Workplace removes its catalog records through `AssetRepository.deleteByWorkplace(id)` but does not imply deletion of original files on disk.

## 11. Current catalog flow

After W1, the conceptual authority is:

```text
Current Workplace
  → WorkplaceController
  → WorkplaceRepository

Workplace assets
  → AssetRepository
```

W2 should add import orchestration on top of these boundaries.

Do not make the file picker itself the catalog owner. File picking is only the source-selection step of an import pipeline.

## 12. W2 target architecture — Import System

The next implementation should introduce an application-level import boundary resembling:

```text
Import UI
  → ImportController / ImportService
    → source discovery
    → supported-format filter
    → duplicate checks
    → optional managed copy
    → metadata/catalog creation
    → AssetRepository
```

The durable flow defined in `docs/WORKPLACES_HANDOFF.md` is:

```text
Select source
  → discover candidate files
  → filter supported types
  → normalize paths
  → check duplicates
  → copy when managed mode is selected
  → read basic metadata
  → create AssetRecord
  → generate/cache preview when appropriate
  → publish into current Workplace
```

Expected W2 concepts:

```text
ImportBatch
ImportState
ImportController / ImportService
linked/add mode
managed/copy mode
progress
cancellation
partial-failure handling
```

Keep picker/filesystem operations out of leaf widgets.

## 13. W3 target state relationship

Grid and Filmstrip must converge on shared catalog state:

```text
Current Workplace
       ↓
Ordered Asset Query
       ├─ Workplace Grid
       └─ Filmstrip

selectedAssetId
       ├─ Grid highlight
       ├─ Filmstrip highlight
       └─ Develop current asset
```

Do not create independent asset arrays or independent selection state for Grid and Filmstrip.

The existing Filmstrip should be evolved rather than duplicated.

## 14. Preview boundary

Workplaces should not depend directly on future RAW processing internals.

A preview abstraction should remain replaceable, conceptually:

```dart
abstract interface class AssetPreviewProvider {
  Future<Uint8List?> thumbnail(AssetRecord asset);
}
```

During the Workplaces phase:

- RAW may use the existing embedded JPEG preview path
- raster images may use the existing raster decode path
- thumbnail/preview caching can be added without introducing real RAW development

## 15. Catalog removal semantics

Keep these concepts separate:

```text
Remove from Workplace
```

and any future destructive filesystem operation such as:

```text
Move Original to Trash…
```

Deleting a Workplace or catalog record must never silently delete the source original.

## 16. Localization

Visible UI strings use `easy_localization`.

Resources:

```text
assets/translations/en.json
assets/translations/th.json
```

New Workplaces/import strings should be translation keys rather than hard-coded widget text.

## 17. Test seams

The architecture should continue to preserve deterministic test boundaries:

```text
Widget tests
  → fake/mocked application state

Controller/service tests
  → repository fakes
  → fake StudioEngine where processing compatibility is involved

Repository tests
  → Hive-backed persistence

Rust tests
  → native processing/core behavior
```

W1 added catalog tests around Workplace persistence and invariants. W2 should add tests for import state transitions, duplicate rules, path normalization, linked/managed decisions, cancellation, and partial failures.

## 18. Validation gate

Core validation:

```bash
flutter pub get
flutter analyze
flutter test

cd rust
cargo check
cargo test
```

Manual regression gate during W2–W4:

- launch and localization
- `My workplace` initialization/restoration
- create/switch/rename/delete Workplace
- existing embedded RAW preview
- raster preview
- Develop
- Subject Mask
- Sky Mask
- LUT
- JPEG export
- responsive workspace behavior

New catalog work must not regress existing processing behavior.

## 19. Current execution order

```text
DONE     W1 Workplace Core
CURRENT  W2 Import System
NEXT     W3 Workplace Browser + Filmstrip
THEN     W4 Desktop Catalog Hardening
FUTURE   PixelCraft external-editor contract
```

See `docs/PROJECT_HANDOFF.md` for canonical current status and `docs/WORKPLACES_HANDOFF.md` for the detailed Workplaces specification.
