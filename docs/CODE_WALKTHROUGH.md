# Dextryx Images — Code Walkthrough

Current code orientation for `dexter-cnx/nixin` during **W4 Desktop Catalog Hardening**.

Detailed W4 rules live in `docs/W4_DESKTOP_CATALOG_HARDENING.md`. Physical desktop gates live in `docs/W4_DESKTOP_VALIDATION.md`.

## Bootstrap and ownership

`lib/main.dart` initializes localization, Riverpod and Hive boxes for settings, Workplaces, assets and import batches.

Top-level ownership remains:

```text
app/          shell/theme/localization
engine/       Rust FFI processing boundary
studio/       Develop/Mask/LUT/Export + Filmstrip + import controls
workplaces/   catalog/import/browser/recovery/thumbnail state and UI
```

Widgets do not access Hive records directly.

## Workplace and catalog core

`WorkplaceController` owns Workplace lifecycle and active Workplace state.

`AssetBrowserController` remains the active Workplace catalog/selection source shared by Grid and Filmstrip. W4-A added missing-file scanning, relink and catalog-only removal.

## ImportController

`lib/workplaces/application/import_controller.dart` owns file/folder discovery, duplicate prevention, linked/managed storage, progress/cancellation, managed copy commit behavior and `ImportBatch` recovery.

Managed import safety from W4-B1 remains:

```text
validate managed root
  -> collision-free destination
  -> copy to .partial
  -> rename to final
  -> persist AssetRecord
```

A missing mount/root is never silently recreated. Copy/catalog failures clean up uncommitted managed output. Persisted recoverable batches are restored per active Workplace and retry keeps the original batch storage mode without mutating the user's configured import mode.

## Asset availability and relink boundary

`AssetFileSystem` / `AssetAvailabilityService` isolate async file availability and folder indexing from Grid tiles.

Availability rules:

- default existence-check batch size is 32;
- stale scan revisions cannot resurrect removed assets or undo relinks;
- only changed `missing` state is persisted;
- filesystem probing failure is a soft failure and does not replace a loaded catalog with an error state.

Relink remains storage-specific:

```text
linked  -> sourcePath
managed -> managedPath
```

## Browser preview resolution

`lib/workplaces/application/asset_preview_provider.dart` resolves browser preview bytes in this order:

```text
AssetRecord.thumbnailPath
  -> AssetRecord.previewPath
  -> AssetThumbnailCache for raster assets
  -> null / placeholder
```

This preserves pre-existing preview/embedded-preview behavior while adding a catalog-local raster cache fallback.

## AssetThumbnailCache

`lib/workplaces/application/asset_thumbnail_cache.dart` owns generated browser thumbnails.

### Scope boundary

The cache accepts only `AssetMediaType.raster` for source generation. RAW assets do not enter `image.decodeImage` here. RAW preview extraction/development remains outside the catalog thumbnail service.

### Generation path

```text
raster effectivePath
  -> async read
  -> compute(_encodeThumbnail)
  -> image decode/resize off synchronous widget build
  -> longest edge <= 512 px
  -> JPEG quality 82
  -> <cache-key>.jpg.partial
  -> rename to <cache-key>.jpg
```

`compute(...)` keeps the decode/resize work away from the synchronous Grid build path.

### Cache identity / invalidation

Generated cache name:

```text
<safe-asset-id>-<modifiedAt.microsecondsSinceEpoch>.jpg
```

A changed persisted `modifiedAt` creates a new version key. When that version is generated, older generated versions for the same asset ID are removed.

### Concurrency and failure behavior

- one in-flight Future per cache path prevents duplicate concurrent generation;
- empty/truncated generated JPEG cache entries are discarded and regenerated;
- missing source assets are not decoded;
- read/write/delete/prune failures are soft failures;
- cache failures never make the catalog unavailable;
- source originals are never modified.

### Filesystem pressure

Default cache bounds:

```text
maxEntries = 2048
maxBytes   = 512 MiB
```

`prune()` orders cache files by modification time and removes oldest files until both limits are satisfied. `.partial` files are excluded from normal cache accounting and handled by generation cleanup.

The cache root is placed beside the Hive assets box on desktop; a system-temp fallback exists only when the Hive box has no filesystem path.

## Workplace browser UI

`GridView.builder` remains lazy. `_AssetThumbnail` requests bytes through `AssetPreviewProvider` and does not synchronously probe original files or decode source images during build.

Grid and Filmstrip continue sharing `AssetBrowserController.assets` and `selectedAssetId`.

## Catalog-only removal

`removeFromWorkplace(assetId)` deletes only the catalog record and updates browser state. It performs no source/managed-original filesystem deletion.

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

### Browser/recovery tests

Cover missing detection/recovery, relink identity, ambiguous filenames, scan-vs-remove races, managed folder recovery and catalog-only removal.

### Managed/import tests

Cover managed-root validation, copy collision/cleanup, restart-safe batch restoration, retry semantics, Workplace gating and storage-mode preservation.

### Thumbnail cache tests

`test/workplaces/asset_thumbnail_cache_test.dart` covers:

- concurrent generation deduplication;
- version invalidation through `modifiedAt`;
- corrupt/truncated cache regeneration;
- RAW decoder exclusion;
- missing-original exclusion;
- oldest-first pruning to configured entry bounds.

### Large-catalog profile tests

`test/workplaces/catalog_profile_test.dart` uses representative in-memory fixtures:

- 5,000 asset load and sort;
- 5,000 availability probes;
- max probe concurrency <= 32;
- no persistence writes when state is unchanged;
- exactly changed-record writes for missing-state transitions.

Stopwatch metrics are captured for diagnostics, but CI does not use machine-specific millisecond thresholds that would be flaky across runners.

## Validation

```bash
flutter pub get
flutter analyze
flutter test

cd rust
cargo check
cargo test
```

Physical external-volume/manual gates are separate from automated CI and must be recorded in `docs/W4_DESKTOP_VALIDATION.md`.

## W4 execution split

```text
W4-A  / PR #12 / merged
  missing detection + relink + catalog-only removal

W4-B1 / PR #13 / merged
  managed destination/copy recovery + import-batch recovery

W4-B2 / current
  raster thumbnail cache hardening
  large-catalog structural/profile gates
  desktop external-volume validation checklist
```

W4 should not be declared fully validated until CI/review is clean and real desktop evidence exists for the manual external-volume gates.
