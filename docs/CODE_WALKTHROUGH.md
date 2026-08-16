# Dextryx Images — Code Walkthrough

Current code orientation for `dexter-cnx/nixin` during **W4 Desktop Catalog Hardening**.

Detailed W4 recovery/acceptance rules live in `docs/W4_DESKTOP_CATALOG_HARDENING.md`.

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

## Asset model recovery semantics

`AssetRecord` remains the stable catalog identity. W4 recovery updates file-location metadata without replacing the record identity.

Relevant path rule:

```text
effectivePath = managedPath ?? sourcePath
```

Storage-specific relink behavior:

```text
linked  -> update sourcePath
managed -> update managedPath
```

`missing` is persisted as catalog state so disconnected originals remain represented across browser sessions.

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

## Missing assets and disconnected volumes

If `effectivePath` is unavailable:

```text
AssetRecord remains in catalog
missing = true
Grid/Filmstrip can retain catalog/preview representation
Develop handoff is blocked for that asset
```

When the path becomes available again, a later scan persists `missing = false`.

This means a disconnected external drive is a recoverable asset-availability condition, not a catalog corruption condition.

## Relink behavior

### Locate Missing File

`AssetBrowserController.relinkAsset()` preserves asset identity and updates only the path appropriate to storage mode.

The replacement path must exist before the catalog record is updated.

### Locate Missing Folder

The selected folder is recursively enumerated once and indexed by lowercase filename.

Automatic matching rule:

```text
0 matches  -> unresolved
1 match    -> relink
2+ matches -> unresolved; do not guess
```

This avoids both repeated O(asset × folder-scan) traversal and unsafe first-match relinking when two folders contain the same filename.

## Catalog-only removal

`removeFromWorkplace(assetId)` calls only `AssetRepository.delete(assetId)` and updates browser selection/list state.

It performs no filesystem delete, move or Trash operation. The original file remains untouched for both linked and managed catalog records.

Any future physical-delete feature must be a separate explicit operation and is outside W4-A.

## Workplace browser UI

`lib/workplaces/ui/workplace_browser.dart` exposes W4-A actions:

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
  -> StudioEngine
    -> RawEngine
      -> Rust C ABI
```

W4 adds no RAW demosaic/debayer or PixelCraft processing code.

## Tests

`test/workplaces/asset_browser_controller_test.dart` covers W3 state behavior plus W4-A cases:

- missing detection persistence
- availability recovery
- single-asset relink with stable asset ID
- batch folder relink with one folder scan
- ambiguous duplicate-filename safety
- catalog-only removal while source-file abstraction remains untouched
- existing Workplace switching/selection/sorting regression behavior

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
W4-A / PR #12
  missing detection
  disconnected-volume behavior
  Locate Missing File
  Locate Missing Folder
  catalog-only removal

W4-B / next
  managed destination/copy recovery
  import-batch recovery/retry
  thumbnail/cache hardening
  representative large-catalog profiling
```

Do not declare W4 complete at the W4-A merge boundary. W4-B remains required unless explicitly moved to a later documented milestone.
