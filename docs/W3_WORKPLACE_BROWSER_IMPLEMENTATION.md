# W3 Workplace Browser + Filmstrip — Implementation Note

Status: in progress on `feature/workplace-browser-filmstrip`.

## Goal

Evolve the W2 catalog/import foundation into a real Workplace browsing surface without moving image-processing ownership out of the existing Studio/Rust path.

## State ownership

`AssetBrowserController` owns the active Workplace asset query, ordered asset list, sort order, and the single `selectedAssetId`.

```text
WorkplaceController.currentWorkplaceId
              ↓
      AssetBrowserController
       ├── ordered assets
       ├── selectedAssetId
       └── sort order
          ↓          ↓
 Workplace Grid   Filmstrip
          \          /
           asset selection
                 ↓
        StudioController
       existing Develop path
```

Grid and Filmstrip must not maintain separate selected-asset state.

## Implemented in this slice

- `AssetBrowserController` and `AssetBrowserState`
- automatic reload on active Workplace change
- refresh after completed/cancelled imports
- import-order, recent-first, and name sorting
- responsive lazy `GridView.builder` Workplace browser
- loading / empty / error browser states
- missing-asset indicator foundation
- `AssetPreviewProvider` boundary for cached thumbnail/preview bytes
- Filmstrip driven by the same ordered catalog assets as the Grid
- Grid/Filmstrip selection through the same `selectedAssetId`
- Workplaces module uses the asset grid as its central surface
- selecting a non-missing asset hands its effective path to the existing Studio Develop path

## Preview boundary

`AssetPreviewProvider` currently reads an existing `thumbnailPath` or `previewPath` when present. It deliberately does not introduce new RAW processing. Import-time thumbnail generation/cache population remains a later W3 hardening step.

## Deferred within W3

- bounded thumbnail generation queue
- persistent thumbnail cache writer/invalidation policy
- viewport-aware prefetching
- explicit missing-file detection/relink (W4 owns full recovery UX)
- advanced ratings/search/filtering

## Validation

Required before merge:

```text
flutter analyze
flutter test
cargo check
cargo test
```

Behavior gates:

- assets from only the active Workplace appear
- Grid and Filmstrip use identical ordering
- Grid selection highlights the same Filmstrip asset
- Filmstrip selection updates the same catalog selection
- selected asset continues to drive existing Develop behavior
- empty/error/loading states remain usable
- missing assets remain catalog-visible and are not sent to Develop
