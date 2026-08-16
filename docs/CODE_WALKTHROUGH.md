# Dextryx Images — Code Walkthrough

Current code orientation for `dexter-cnx/nixin` after **W4-B2 Desktop Catalog Hardening**, including the repository CI execution architecture.

Detailed W4 rules live in `docs/W4_DESKTOP_CATALOG_HARDENING.md`. Physical desktop gates live in `docs/W4_DESKTOP_VALIDATION.md`; execution/evidence steps live in `docs/W4_VALIDATION_RUNBOOK.md`. CI details live in `docs/CI_ARCHITECTURE.md`.

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
  -> stat source
  -> bounded generation queue
  -> async read
  -> compute(_encodeThumbnail)
  -> image decode/resize off synchronous widget build
  -> longest edge <= 512 px
  -> JPEG quality 82
  -> <cache-key>.jpg.partial
  -> rename to <cache-key>.jpg
  -> awaited prune
```

`compute(...)` keeps decode/resize work away from the synchronous Grid build path. Distinct raster generations are bounded (default two at a time), while duplicate requests for the same cache path share one in-flight Future.

### Cache identity / invalidation

Generated cache identity combines:

```text
stable AssetRecord.id
persisted AssetRecord.modifiedAt
current source file modified time
current source file size
```

The source is stat-checked again around the read. If the file changes while generation is in progress, that generation is discarded instead of committing a stale cache entry. When a new version is generated, older generated versions for the same asset ID are removed.

### Cache validation and failure behavior

- generated JPEG entries are decode-validated before reuse, not accepted from marker bytes alone;
- invalid/corrupt entries are deleted and regenerated;
- missing source assets are not decoded;
- read/write/delete/prune failures are soft failures;
- prune is awaited so no maintenance Future escapes thumbnail/test lifecycle;
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

W4 and CI optimization add no RAW demosaic/debayer or PixelCraft processing code.

## Tests

### Browser/recovery tests

Cover missing detection/recovery, relink identity, ambiguous filenames, scan-vs-remove races, managed folder recovery and catalog-only removal.

### Managed/import tests

Cover managed-root validation, copy collision/cleanup, restart-safe batch restoration, retry semantics, Workplace gating and storage-mode preservation.

### Thumbnail cache tests

`test/workplaces/asset_thumbnail_cache_test.dart` covers:

- same-version concurrent request deduplication;
- distinct generation concurrency cap;
- source metadata invalidation;
- corrupt cache regeneration;
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

## Validation tooling

`tool/w4-desktop-validation.sh` standardizes physical validation evidence.

```bash
make w4-validation-preflight
make w4-validation-automated
```

`preflight` records commit/branch, dirty state, OS/toolchain, devices and disk/mount snapshot under `build/w4-validation/<timestamp>/`.

`automated` records the same evidence and runs Flutter analysis, focused Workplaces browser/import/thumbnail/profile tests, `cargo check` and `cargo test`.

The tooling deliberately does not mark D1-D8 physical gates PASS.

## CI execution architecture

CI has one path classifier and two workflows.

### Central classifier

`tool/ci-detect-changes.sh` receives base/head SHAs and emits domains used by downstream job-level conditions:

```text
docs
flutter
rust
ffi
platform_android / platform_ios / platform_macos / platform_windows / platform_linux
import_filesystem
export_engine
ci
```

CI/build-system changes deliberately broaden all domains. Path classification is not copied into individual platform jobs.

### PR workflow

`.github/workflows/ci.yml` is structured as:

```text
Detect changes
    -> Fast CI
        -> Flutter full tests       (when affected)
        -> Rust full tests          (when affected)
        -> Android build            (when affected)
        -> iOS no-sign build        (when affected)
        -> macOS build              (when affected)
        -> Windows build            (when affected)
        -> Linux build              (when affected)
             \______________________________/
                         |
                         v
                  PR CI required
```

All expensive jobs depend on `Fast CI`, so Dart/Rust formatting, static-analysis, Clippy or compile errors fail before macOS/Windows/mobile runners start.

`PR CI required` uses `if: always()` and treats only `success` or intentional `skipped` results as acceptable. The workflow itself is never path-filtered.

### Full validation workflow

`.github/workflows/full-validation.yml` runs without path filtering for non-draft pull requests targeting `main`, and it also supports explicit manual full runs. Draft pull requests defer the expensive full matrix; marking a draft ready triggers the workflow. A newer commit pushed to the same pull request cancels obsolete in-progress full-validation work.

```text
Full preflight
    -> all Flutter tests
    -> all Rust tests/release native build
    -> Android release
    -> iOS release --no-codesign
    -> macOS release
    -> Windows release
    -> Linux release
         |
         v
      Merge gate
```

On a ready pull request, the full matrix is expected to execute and `Merge gate` requires every required full-validation dependency to succeed. Draft-PR deferral is handled by not running the expensive matrix until the PR is ready, rather than treating a skipped full matrix as merge-ready validation.

The workflow retains `merge_group` compatibility for a future repository configuration where Merge Queue is available, but the current personal-account branch-protection contract does not depend on Merge Queue.

### Local equivalent

`Makefile` exposes:

```text
make format-check
make analyze
make test-fast
make rust-format-check
make rust-clippy
make rust-check
make ci-fast
make preflight
make validate
```

`make preflight` is the recommended before-push command.

## Branch-protection boundary

Repository settings are part of the CI contract but are not stored in source. This repository is currently under a personal GitHub account, where Merge Queue is unavailable. Protected `main` should require the stable checks `PR CI required` and `Merge gate`, and **Require branches to be up to date before merging** should be enabled so the ready PR is validated against the latest `main` before merge. `Merge gate` therefore reports on normal ready pull requests in the current configuration. See `docs/CI_ARCHITECTURE.md` for the exact current contract and the GitHub App limitation around inspecting or modifying branch protection.

## W4 execution split

```text
W4-A  / PR #12 / merged
  missing detection + relink + catalog-only removal

W4-B1 / PR #13 / merged
  managed destination/copy recovery + import-batch recovery

W4-B2 / PR #14 / merged
  raster thumbnail cache hardening
  large-catalog structural/profile gates

PARALLEL OUTSTANDING
  physical D1-D8 removable-volume/UI evidence
```

W4 code is complete through PR #14. The milestone remains physically **NOT VALIDATED** until D1-D8 are run on a real desktop filesystem or an explicit documented deferral is approved.
