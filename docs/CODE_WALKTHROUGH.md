# Dextryx Images — Code Walkthrough

Current code orientation for `dexter-cnx/nixin` after W3 Workplace Browser + Filmstrip implementation.

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
  studio/       Develop/Mask/LUT/Export compatibility UI + Filmstrip
  workplaces/   Workplace/catalog/import/browser state and UI
```

## Workplace core

`lib/workplaces/application/workplace_controller.dart` owns Workplace lifecycle and persistence-facing application state.

Responsibilities include:

- initialize/restore Workplaces
- create default `My workplace`
- create / switch / rename / delete
- preserve the last-Workplace invariant
- expose the active Workplace ID used by browser/import flows

Widgets do not access Hive directly.

## Import system

`ImportController` owns file/folder selection, discovery, duplicate filtering, linked/managed storage behavior, catalog writes, progress, cancellation and `ImportBatch` persistence.

Import remains catalog orchestration, not image processing.

## Asset browser state

`lib/workplaces/application/asset_browser_controller.dart` introduces the W3 catalog selection boundary.

`AssetBrowserState` owns:

```text
workplaceId
assets
selectedAssetId
sortOrder
loading
errorMessage
```

`AssetBrowserController`:

- listens to active Workplace changes
- queries `AssetRepository.getByWorkplace()`
- refreshes after completed/cancelled imports
- sorts the active list
- owns the single selected asset ID
- clears stale assets and selection immediately when switching Workplaces
- keeps failed queries from exposing the previous Workplace's assets
- can select an imported asset by effective path after catalog refresh

The browser uses revision-based load protection so a stale async query cannot overwrite a newer Workplace load.

## Workplace browser UI

`lib/workplaces/ui/workplace_browser.dart` renders the Workplaces module central surface.

It provides:

- responsive lazy `GridView.builder`
- loading state
- empty state
- error/retry state
- basic sort control
- selected tile indication
- missing-asset indicator foundation
- thumbnail display through `AssetPreviewProvider`

The browser does not decode full RAW sensor data.

## Preview boundary

`lib/workplaces/application/asset_preview_provider.dart` defines:

```dart
abstract interface class AssetPreviewProvider {
  Future<Uint8List?> thumbnail(AssetRecord asset);
}
```

The current local provider reads existing `thumbnailPath` or `previewPath` cache files. This keeps the browser independent from future RAW-engine or PixelCraft processing internals.

Thumbnail generation/cache writing can be hardened later without changing Grid/Filmstrip ownership.

## Filmstrip synchronization

`lib/studio/filmstrip.dart` no longer treats the currently developed file as a one-item strip.

Instead, Grid and Filmstrip consume the same `AssetBrowserState.assets` ordered list and the same `selectedAssetId`.

Conceptually:

```text
active Workplace
      ↓
AssetBrowserController
      ├── ordered assets → Workplace Grid
      ├── ordered assets → Filmstrip
      └── selectedAssetId
             ├── Grid highlight
             ├── Filmstrip highlight
             └── Develop current asset
```

Missing assets remain visible in the catalog but are not sent to Develop.

## Post-import selection

`lib/studio/studio_import_controls.dart` synchronizes imported catalog selection before opening the latest imported asset in Develop.

Flow:

```text
ImportController completes
  → AssetBrowserController.refresh()
  → select imported AssetRecord by effectivePath
  → StudioController.selectRawPath(effectivePath)
  → StudioController.develop()
```

This avoids a split-brain state where Develop shows a newly imported image while Grid/Filmstrip still highlight an older asset.

## Studio module integration

`lib/studio/studio_page.dart` switches the central surface by module:

- **Workplaces** → catalog Grid
- **Develop / Export** → existing Studio preview surface

The existing editor/processing controls remain intact.

## Processing boundary

Processing remains unchanged:

```text
StudioController
  → StudioEngine
    → RawEngine
      → Rust C ABI
```

W3 adds no sensor RAW demosaic/debayer, new adjustment semantics, GPU processing, or PixelCraft processing code.

## Tests

W3 adds/extends `test/workplaces/asset_browser_controller_test.dart` coverage for:

- active Workplace filtering
- import-order loading
- selection as a single source of truth
- selection survival across refresh
- Workplace switching clears incompatible selection
- failed Workplace switch/query clears stale assets
- imported asset selection by effective path
- recent-first and filename sorting

Existing import, Workplace and Studio tests remain regression coverage.

## Validation

```bash
flutter pub get
flutter analyze
flutter test

cd rust
cargo check
cargo test
```

The W3 review-fix head passed CI before this documentation sync. The final documentation commit must also pass the normal PR CI gate before merge.

## Next — W4

W4 hardens the catalog for desktop use: missing-file detection/relink, disconnected volumes, managed-storage/file failure recovery, catalog-only removal, import recovery and large-catalog performance profiling. New RAW/image-processing work remains deferred.
