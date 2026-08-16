# Dextryx Images — Code Walkthrough

This is the current code orientation for `dexter-cnx/nixin` during **W2 Import System + live Workplace wiring**.

## Bootstrap

`lib/main.dart` initializes localization, Riverpod and Hive boxes:

```text
studio_settings
workplaces
assets
import_batches
```

## Top-level ownership

```text
lib/
  app/          app shell/theme/localization
  engine/       Rust FFI processing boundary
  studio/       preview/Develop/Mask/LUT/Export compatibility UI
  workplaces/   catalog, Workplace state and import orchestration
```

## Workplace core

`lib/workplaces/application/workplace_controller.dart` owns:

```text
WorkplaceState
WorkplaceController
workplaceControllerProvider
workplaceRepositoryProvider
assetRepositoryProvider
```

The live Studio UI now consumes `workplaceControllerProvider` through `StudioImportControls`, so Riverpod creates the controller and `initialize()` performs real launch-time Workplace initialization.

`initialize()` loads Workplaces, creates `My workplace` when empty, restores/repairs current Workplace ID, and publishes ready state.

The visible W2 controls allow switching, creating, renaming and deleting Workplaces while preserving the last-Workplace invariant.

## Import domain

New W2 domain pieces:

```text
lib/workplaces/domain/import_batch.dart
lib/workplaces/domain/repositories/import_repository.dart
```

`ImportBatch` records one import operation including source type, requested/imported/duplicate/failed counts, timestamps and terminal status.

## Import persistence

```text
lib/workplaces/data/hive/hive_import_repository.dart
```

`HiveImportRepository` persists batches in `import_batches` and supports lookup by ID and Workplace.

## Import application state

```text
lib/workplaces/application/import_state.dart
lib/workplaces/application/import_controller.dart
```

`ImportState` exposes:

```text
phase
storageMode
total / processed
imported
skippedDuplicates
failed
currentFile
lastImportedPath
batch
errorMessage
```

Import phases:

```text
idle
selecting
scanning
checkingDuplicates
copying
cataloging
completed
cancelled
failed
```

`ImportController` owns source selection and catalog orchestration. The Studio UI does not own file discovery or Hive writes.

## Import flow

Multi-file path:

```text
FilePicker multi-select
  → supported extension filter
  → normalize absolute paths
  → load active Workplace assets
  → duplicate check by normalized source path
  → optional managed copy
  → create AssetRecord
  → AssetRepository.save
  → persist ImportBatch
  → publish terminal ImportState
  → hand latest imported effectivePath to StudioController
  → existing Develop preview path
```

Folder path:

```text
FilePicker directory
  → Directory.list(recursive: true by default)
  → supported file filter
  → same catalog pipeline
```

A current-folder-only option passes `recursive: false`.

## Storage modes

`AssetStorageMode.linked` keeps the original in place and catalogs `sourcePath`.

`AssetStorageMode.managed` asks for a managed root when one is not already stored, remembers it in `studio_settings`, and copies originals under:

```text
<managed-root>/originals/YYYY/MM/DD/<asset-id>-<filename>
```

`sourcePath` and `managedPath` remain separate; Workplace display names do not drive filesystem layout.

## Cancellation and partial failure

`ImportController.cancel()` sets a cancellation request. The per-file loop stops before starting the next asset, preserving already cataloged assets and writing a cancelled `ImportBatch`.

Per-file filesystem/catalog errors increment `failed` and do not abort later candidates.

The loop yields with `Future.delayed(Duration.zero)` between candidates so large batches do not monopolize the UI isolate continuously.

## Studio integration

`lib/studio/studio_import_controls.dart` is the presentation adapter between live Workplace/import state and the existing Studio preview.

It provides:

- current Workplace dropdown
- create/rename/delete Workplace menu
- primary multi-select Import
- folder import menu
- linked/managed storage selection
- progress/cancel/summary UI
- latest imported asset handoff to `StudioController.selectRawPath()` then `develop()`

`lib/studio/studio_page.dart` now uses these controls in wide, medium and compact compositions instead of the legacy direct Open Image action.

The existing `StudioController.pickRaw()` remains as legacy compatibility code but is no longer the primary Studio entry UI.

## Processing boundary

Processing remains unchanged:

```text
StudioController
  → StudioEngine
    → RawEngine
      → Rust C ABI
```

W2 does not add RAW demosaic/debayer, new adjustment semantics, GPU processing, or PixelCraft processing code.

## Tests

`test/workplaces/import_controller_test.dart` covers:

- supported file import and batch persistence
- duplicate source-path prevention
- managed-copy behavior while preserving original
- unsupported-file filtering

Existing Workplace and Studio tests remain regression coverage.

## Validation

```bash
flutter pub get
flutter analyze
flutter test

cd rust
cargo check
cargo test
```

Manual W2 gate should include multi-select import, nested folder import, linked mode, managed mode, cancellation, restart persistence, Workplace CRUD, and existing RAW/raster preview + Develop/Mask/LUT/JPEG export.

## Next

After W2 merges, W3 makes the catalog visible as the primary Workplace Grid and evolves Filmstrip to share the same ordered assets and selected-asset truth.
