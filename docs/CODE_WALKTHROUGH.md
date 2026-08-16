# Dextryx Images — Code Walkthrough

Current code orientation for `dexter-cnx/nixin` during **W4 Desktop Catalog Hardening**.

## Bootstrap and ownership

`lib/main.dart` initializes localization, Riverpod and Hive boxes for settings, Workplaces, assets and import batches.

Top-level ownership remains:

```text
app/          shell/theme/localization
engine/       Rust FFI processing boundary
studio/       Develop/Mask/LUT/Export + Filmstrip
workplaces/   catalog/import/browser/recovery state and UI
```

Widgets do not access Hive directly.

## Workplace and import core

`WorkplaceController` owns Workplace lifecycle and active Workplace state.

`ImportController` owns file/folder selection, duplicate prevention, linked/managed import, progress/cancellation and `ImportBatch` persistence.

These remain catalog concerns; image-processing behavior is unchanged.

## Asset browser state

`lib/workplaces/application/asset_browser_controller.dart` owns:

```text
workplaceId
ordered assets
selectedAssetId
sortOrder
loading
scanningAvailability
errorMessage
```

It remains the single catalog selection source shared by Workplace Grid and Filmstrip.

W4 extends it with:

- automatic/manual availability scans
- missing-state persistence
- single-file relink
- missing-folder batch relink
- catalog-only removal

Load revisions and availability-scan revisions prevent stale async work from overwriting a newer Workplace state.

## Filesystem availability boundary

`lib/workplaces/application/asset_availability_service.dart` introduces:

```text
AssetFileSystem
LocalAssetFileSystem
AssetAvailabilityService
```

This keeps direct filesystem probing out of Grid tiles and repository widgets.

Availability checks run asynchronously in bounded batches of 32 and yield between batches. Only assets whose `missing` state changes are persisted again.

An availability-scan failure does not convert a successfully loaded catalog into a browser error state; the catalog remains usable even when an external volume is unavailable or filesystem probing fails.

## Missing assets

The effective file path remains:

```text
managedPath ?? sourcePath
```

If that path is unavailable:

```text
AssetRecord remains in catalog
missing = true
Grid/Filmstrip can still show cached catalog/preview state
Develop handoff is blocked for the missing asset
```

When the path becomes available again, the next scan persists `missing = false`.

## Relink behavior

### Locate Missing File

`AssetBrowserController.relinkAsset()` preserves asset identity and updates only the path appropriate to storage mode:

```text
linked  → sourcePath
managed → managedPath
```

The replacement must exist before the catalog record is updated.

### Locate Missing Folder

The selected folder is recursively enumerated once and indexed by lowercase filename.

For each missing asset:

- exactly one filename match → relink automatically
- zero matches → remain missing
- multiple matches → remain missing; do not guess

This avoids both repeated O(asset × folder-scan) traversal and unsafe first-match relinking.

## Catalog-only removal

`removeFromWorkplace(assetId)` calls only `AssetRepository.delete(assetId)` and updates browser selection/list state.

It performs no filesystem delete, move or Trash operation.

The UI confirmation explicitly states that the original file remains untouched.

## Workplace browser UI

`lib/workplaces/ui/workplace_browser.dart` now exposes:

- missing count
- availability rescan
- Locate Missing Folder
- per-asset Locate Missing File
- per-asset Remove from Workplace
- missing indicator

Existing responsive lazy Grid construction and sorting remain unchanged.

## Filmstrip / Develop relationship

Grid and Filmstrip still consume the same ordered assets and `selectedAssetId`.

Missing assets remain visible but are not sent to `StudioController` for Develop.

Processing remains:

```text
StudioController
  → StudioEngine
    → RawEngine
      → Rust C ABI
```

W4 does not add RAW demosaic/debayer or PixelCraft processing code.

## Tests

`test/workplaces/asset_browser_controller_test.dart` covers W3 state behavior plus W4 cases:

- missing detection persistence
- availability recovery
- single-asset relink with stable asset ID
- batch folder relink with one folder scan
- catalog-only removal while source-file abstraction remains untouched

## Validation

```bash
flutter pub get
flutter analyze
flutter test

cd rust
cargo check
cargo test
```

## Remaining W4 work

After this missing/relink/removal slice, continue with managed-copy recovery, import-batch recovery, thumbnail-cache hardening and representative large-catalog profiling before declaring W4 complete.
