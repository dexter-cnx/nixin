# Dextryx Images — Project Handoff

> Canonical current status and execution queue for `dexter-cnx/nixin`.

## Current status

- Product: **Dextryx Images**
- Compact app label: **Dxtr Imgs**
- Canonical application/bundle ID: `com.cnxdev.dextryx.images`
- Repository remains `dexter-cnx/nixin`
- Studio workspace UI-01 through UI-15: complete
- **W1 Workplace Core: merged**
- **W2 Import System + live Workplace wiring: merged**
- **W3 Workplace Browser + Filmstrip: merged in PR #11**
- W3 merge commit on `main`: `3a8dda81efec1f3d81cae6291f057dd255f8cb75`
- Current branch: `feature/desktop-catalog-hardening`
- Current milestone: **W4 — Desktop Catalog Hardening**
- Real RAW demosaic/debayer and other new image-processing work remain deferred.

## Product responsibility

Dextryx Images owns Workplaces, catalog identity, import/storage organization, thumbnail/preview browsing, Grid/Filmstrip selection, missing/relink workflows, catalog metadata, large-library UX and future external-edit orchestration.

PixelCraft / Dextryx Pixels remains processing authority. Do not duplicate its processing roadmap here.

## Completed — W1 to W3

W1 established Workplace/AssetRecord persistence and lifecycle.

W2 added live Workplace wiring plus multi-file/folder Import, linked/managed storage, ImportBatch persistence, duplicate prevention, progress and cancellation.

W3 added the persisted Workplace Grid, `AssetBrowserController`, one ordered asset list, one `selectedAssetId`, Grid ↔ Filmstrip synchronization, basic sorting, preview boundary and missing-indicator foundation.

## Current — W4 Desktop Catalog Hardening

### W4-A — Missing/relink/removal foundation

Current branch implements:

- filesystem availability abstraction separate from widgets/Hive
- asynchronous asset availability scans
- bounded file-existence concurrency in batches of 32
- `AssetRecord.missing` persistence only when state changes
- automatic availability scan after Workplace load plus manual rescan action
- disconnected/missing originals remain visible in catalog
- missing assets are not opened into Develop
- **Locate Missing File…** for single-asset relink
- **Locate Missing Folder…** for recursive batch relink
- batch folder scan is indexed once instead of rescanning per asset
- automatic folder relink only when filename match is unique; ambiguous duplicates remain unresolved
- linked relink updates `sourcePath`
- managed relink updates `managedPath`
- catalog identity (`AssetRecord.id`) remains stable across relink
- **Remove from Workplace** deletes only the catalog record
- removal explicitly does not delete/move the original file

### W4-B — Remaining hardening after W4-A is merged

Still required before W4 is complete:

- managed-storage destination/recovery hardening
- managed-copy collision and filesystem failure recovery
- import-batch recovery / retry semantics
- thumbnail generation/cache hardening where needed by real catalog use
- representative large-catalog profiling and performance measurements
- additional desktop/manual external-volume recovery gates

Do not claim W4 complete until these remaining items are either implemented or deliberately moved to a later documented milestone.

## W4 guardrails

- catalog removal and physical deletion are separate operations
- linked originals are never silently moved or deleted
- missing/disconnected linked assets stay cataloged
- Workplace rename never moves managed originals
- availability failures must not make the catalog itself unavailable
- no synchronous filesystem checks per Grid tile
- no broad state-management rewrite solely for W4
- no new RAW/image-processing scope

## Regression gates

Every Workplaces/catalog PR must preserve:

- embedded RAW preview behavior
- raster preview
- Develop adjustments
- Subject/Sky masks
- LUT
- JPEG export

Automated gate:

```text
flutter analyze
flutter test
cargo check
cargo test
```

## Future — PixelCraft external-editor integration

Only after catalog workflows stabilize. Dextryx Images remains catalog authority; PixelCraft remains processing authority. Future integration should exchange stable asset/edit references rather than duplicate processing internals.

## Immediate execution order

```text
CURRENT   W4-A missing/relink/catalog-removal hardening
NEXT      W4-B managed/import/cache/performance hardening
FUTURE    PixelCraft external-editor contract
```
