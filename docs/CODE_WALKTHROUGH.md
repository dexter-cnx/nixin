# Dextryx Images — Code Walkthrough

Current code orientation for `dexter-cnx/nixin` during **W4 Desktop Catalog Hardening**.

Detailed W4 recovery/acceptance rules live in `docs/W4_DESKTOP_CATALOG_HARDENING.md`.

## Bootstrap and ownership

`lib/main.dart` initializes localization, Riverpod and Hive boxes for settings, Workplaces, assets and import batches.

Top-level ownership remains:

```text
app/          shell/theme/localization
engine/       Rust FFI processing boundary
studio/       Develop/Mask/LUT/Export + Filmstrip + import controls
workplaces/   catalog/import/browser/recovery state and UI
```

Widgets do not access Hive directly.

## Workplace and catalog core

`WorkplaceController` owns Workplace lifecycle and active Workplace state.

`AssetBrowserController` remains the active Workplace catalog/selection source shared by Grid and Filmstrip. W4-A added missing-file scanning, relink and catalog-only removal; those semantics remain unchanged in W4-B.

## ImportController

`lib/workplaces/application/import_controller.dart` owns file/folder discovery, duplicate prevention, linked/managed storage, progress/cancellation, managed copy commit behavior and `ImportBatch` recovery.

The import path remains catalog orchestration only; image processing is not performed here.

### Managed destination validation

Managed imports read the remembered managed destination from `ImportPreferences`.

```text
remembered destination exists
  -> use it

remembered destination missing/unmounted
  -> do NOT recreate it
  -> ask for a replacement destination
  -> validate replacement exists
  -> persist replacement preference
```

This avoids accidentally creating an ordinary local directory at a path that normally belongs to a disconnected external volume.

### Managed copy commit protocol

For each managed source:

```text
source
  -> choose collision-free final path
  -> copy to <final>.partial
  -> rename partial to final
  -> write AssetRecord
```

Safety rules:

- an existing managed destination file is never overwritten;
- generated asset IDs are checked against catalog persistence;
- failed copy removes the partial file;
- cancellation after copy but before catalog commit removes the new managed copy;
- catalog-save failure removes the newly copied managed original;
- the source original remains untouched.

## ImportBatch recovery model

`lib/workplaces/domain/import_batch.dart` now persists:

```text
sourcePaths
failedPaths
storageMode
status
counts / timestamps / source metadata
```

A `running` batch is persisted before per-file processing starts. If the app terminates during import, that record retains the candidate source list required for a later retry.

Backward compatibility is retained for older Hive maps:

```text
missing sourcePaths -> []
missing failedPaths -> []
missing storageMode -> linked
```

## Retry semantics

`ImportController.retryBatch(batchId)`:

1. requires the original Workplace to be active;
2. uses `failedPaths` when the prior batch completed/failed partially;
3. uses all `sourcePaths` when recovering an interrupted `running` batch;
4. uses the **original batch storage mode**, not the current UI option;
5. creates a new import attempt/batch rather than mutating historical results;
6. relies on existing source-path duplicate detection so already-successful assets are not duplicated.

The Studio import controls expose failed status plus **Retry failed import** when the current batch is recoverable.

## Asset availability and relink boundary

W4-A introduced `AssetFileSystem` / `AssetAvailabilityService` for asynchronous file availability and folder indexing. No synchronous `File.exists()` calls are made per Grid tile.

Availability scans use revision guards so stale scans cannot resurrect removed assets or undo relinks.

Relink remains storage-specific:

```text
linked  -> sourcePath
managed -> managedPath
```

Managed folder recovery matches the stored managed filename, not `originalFilename`, because managed copies use an asset-ID-prefixed filename.

## Catalog-only removal

`removeFromWorkplace(assetId)` deletes only the catalog record and updates browser state. It performs no filesystem delete, move or Trash operation.

## Processing boundary

Processing remains unchanged:

```text
StudioController
  -> StudioEngine
    -> RawEngine
      -> Rust C ABI
```

W4 adds no RAW demosaic/debayer or PixelCraft processing code.

## Tests

W4-A browser tests cover:

- missing detection/recovery;
- relink identity;
- duplicate filename ambiguity;
- scan-vs-remove race protection;
- managed-folder filename recovery;
- catalog-only removal.

W4-B import tests cover:

- managed copy success;
- missing remembered managed root replacement without recreating the stale path;
- destination collision safety;
- cleanup when catalog save fails;
- recoverable failed-path persistence;
- retry without duplicating prior successes;
- original-Workplace retry requirement;
- legacy `ImportBatch` map compatibility.

## Validation

```bash
flutter pub get
flutter analyze
flutter test

cd rust
cargo check
cargo test
```

## W4 execution split

```text
W4-A / PR #12 / merged
  missing detection
  disconnected-volume behavior
  Locate Missing File / Folder
  catalog-only removal

W4-B / current
  managed destination recovery
  collision-safe managed copy commit
  import-batch recovery/retry

W4-B / next
  thumbnail/cache hardening
  representative large-catalog profiling
```

W4 is not complete until the remaining thumbnail/cache and large-catalog gates are finished or deliberately moved to a documented later milestone.
