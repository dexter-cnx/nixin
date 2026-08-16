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
- **W4-A missing/relink/catalog-removal hardening: merged in PR #12**
- **W4-B1 managed/import recovery: merged in PR #13**
- W4-B1 merge commit on `main`: `070aa61c069238969aae99da6bd5dd0bb97730e4`
- Current branch: `feature/w4b-thumbnail-catalog-profiling`
- Current milestone: **W4-B2 — Thumbnail/cache + large-catalog hardening**
- Detailed W4 guide: `docs/W4_DESKTOP_CATALOG_HARDENING.md`
- Desktop validation checklist: `docs/W4_DESKTOP_VALIDATION.md`
- Real RAW demosaic/debayer and other new image-processing work remain deferred.

## Product responsibility

Dextryx Images owns Workplaces, catalog identity, import/storage organization, thumbnail/preview browsing, Grid/Filmstrip selection, missing/relink workflows, catalog metadata, large-library UX and future external-edit orchestration.

PixelCraft / Dextryx Pixels remains processing authority. Do not duplicate its processing roadmap here.

## Completed — W1 through W4-B1

W1 established Workplace/AssetRecord persistence and lifecycle.

W2 added live Workplace wiring plus multi-file/folder Import, linked/managed storage, ImportBatch persistence, duplicate prevention, progress and cancellation.

W3 added the persisted Workplace Grid, `AssetBrowserController`, one ordered asset list, one `selectedAssetId`, Grid ↔ Filmstrip synchronization, basic sorting and preview boundary.

W4-A added asynchronous missing-file detection, disconnected-volume behavior, single-file/folder relink, managed-copy filename relink correctness, availability-scan race protection and catalog-only removal.

W4-B1 added validated managed destinations, collision-safe/atomic managed copies, cleanup after copy/catalog failures, restart-safe ImportBatch restoration/retry, original-Workplace retry gating and preservation of user-selected storage preferences.

## Current — W4-B2 Thumbnail/cache + large-catalog hardening

Current branch implements:

### Thumbnail/cache

- `AssetThumbnailCache` is a catalog/browser service separate from RAW processing;
- existing persisted `thumbnailPath` / `previewPath` still take precedence;
- raster assets without an existing preview can lazily generate a browser thumbnail;
- RAW assets do **not** enter the raster decoder path and continue to rely on existing embedded/persisted preview boundaries;
- raster decode/resize runs through `compute(...)`, outside the UI-critical synchronous build path;
- generated thumbnails are capped to 512 px on the longest edge and encoded as JPEG;
- cache writes use `<final>.partial` followed by rename;
- concurrent requests for the same asset/version share one in-flight generation Future;
- cache keys include stable asset ID plus persisted `modifiedAt`, so a new asset version gets a new cache key;
- stale versions for the same asset are removed when a new version is generated;
- invalid/truncated generated JPEG cache files are discarded and regenerated;
- cache failures are soft failures and never make the Workplace catalog unavailable;
- cache pruning defaults to 2,048 files / 512 MiB and removes oldest entries first;
- missing assets are not decoded from unavailable originals.

### Large-catalog profile gates

Representative automated fixtures now exercise:

- 5,000-asset Workplace load;
- 5,000-asset in-memory sort;
- 5,000-asset availability scan;
- availability concurrency bound of 32;
- zero persistence writes when availability state is unchanged;
- exact write amplification when only a subset changes missing state;
- elapsed load/sort/scan metrics are captured by the profile tests for diagnosis.

These are structural regression/profile gates rather than fragile machine-specific latency thresholds.

### Desktop external-volume validation

`docs/W4_DESKTOP_VALIDATION.md` defines the physical/manual gates for:

- linked external-volume disconnect/reconnect;
- managed destination disconnect before import;
- managed destination disconnect during import;
- replacement managed destination;
- restart recovery of persisted running/failed batches;
- cache corruption/recovery;
- representative large-catalog interaction while background availability/cache work occurs.

## W4 guardrails

- catalog removal and physical deletion are separate operations;
- linked originals are never silently moved or deleted;
- missing/disconnected linked assets stay cataloged;
- a missing managed mount/root must not be silently recreated at the same path;
- managed copy must not overwrite an existing file;
- failed catalog writes must not leave newly copied managed originals orphaned;
- import retry must preserve catalog identity/duplicate safety and original storage semantics;
- thumbnail generation must not introduce RAW development/processing ownership into Workplaces;
- no synchronous source decode or filesystem existence probe inside Grid tile build;
- cache corruption/failure is recoverable and must not fail the catalog;
- no broad state-management rewrite solely for W4;
- no new RAW/image-processing scope.

## Regression gates

Every Workplaces/catalog PR must preserve:

- embedded RAW preview behavior;
- raster preview;
- Develop adjustments;
- Subject/Sky masks;
- LUT;
- JPEG export.

Automated gate:

```text
flutter analyze
flutter test
cargo check
cargo test
```

W4-B2 additionally includes the large-catalog profile tests under `test/workplaces/catalog_profile_test.dart`.

## Documentation map

```text
docs/PROJECT_HANDOFF.md                    canonical project status / execution queue
docs/CODE_WALKTHROUGH.md                   current code ownership and data flow
docs/W4_DESKTOP_CATALOG_HARDENING.md       W4 implementation/recovery/acceptance guide
docs/W4_DESKTOP_VALIDATION.md              W4 physical desktop validation checklist
```

## W4 completion boundary

W4-B2 code is complete only after:

1. thumbnail/cache and profile tests are green in CI;
2. review findings are resolved;
3. desktop/manual gates in `docs/W4_DESKTOP_VALIDATION.md` are either recorded PASS or explicitly documented as deferred/manual follow-up.

Do not claim physical external-volume gates passed without real desktop evidence.

## Future — PixelCraft external-editor integration

Only after catalog workflows stabilize. Dextryx Images remains catalog authority; PixelCraft remains processing authority. Future integration should exchange stable asset/edit references rather than duplicate processing internals.

## Immediate execution order

```text
DONE      W4-A  PR #12 missing/relink/catalog-removal hardening
DONE      W4-B1 PR #13 managed destination/copy + import-batch recovery
CURRENT   W4-B2 thumbnail/cache + large-catalog profile gates
GATE      desktop/manual external-volume validation
FUTURE    PixelCraft external-editor contract
```
