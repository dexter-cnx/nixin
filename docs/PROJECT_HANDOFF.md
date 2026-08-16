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
- W4-A merge commit on `main`: `f5fb16bdf84f61d92fe93dc7f03c35777227df3b`
- Current branch: `feature/w4b-managed-import-recovery`
- Current milestone: **W4-B — Managed/import recovery**
- Detailed W4 implementation/acceptance guide: `docs/W4_DESKTOP_CATALOG_HARDENING.md`
- Real RAW demosaic/debayer and other new image-processing work remain deferred.

## Product responsibility

Dextryx Images owns Workplaces, catalog identity, import/storage organization, thumbnail/preview browsing, Grid/Filmstrip selection, missing/relink workflows, catalog metadata, large-library UX and future external-edit orchestration.

PixelCraft / Dextryx Pixels remains processing authority. Do not duplicate its processing roadmap here.

## Completed — W1 to W4-A

W1 established Workplace/AssetRecord persistence and lifecycle.

W2 added live Workplace wiring plus multi-file/folder Import, linked/managed storage, ImportBatch persistence, duplicate prevention, progress and cancellation.

W3 added the persisted Workplace Grid, `AssetBrowserController`, one ordered asset list, one `selectedAssetId`, Grid ↔ Filmstrip synchronization, basic sorting and preview boundary.

W4-A added asynchronous missing-file detection, disconnected-volume behavior, single/file-folder relink, managed-copy filename relink correctness, availability-scan race protection and catalog-only removal.

## Current — W4-B Managed/import recovery

Current branch implements:

- validates remembered managed-original destination before import;
- a missing remembered destination is treated as unavailable/disconnected and is **not recreated automatically**;
- user can select a replacement managed destination and the preference is updated only after validation;
- managed copy uses a temporary `.partial` file followed by rename;
- existing destination files are never overwritten; collisions receive a unique destination path;
- asset IDs are collision-checked against catalog persistence;
- a managed file copied successfully but followed by catalog-save failure is cleaned up;
- cancellation after a managed copy cleans up the uncommitted managed copy;
- `ImportBatch` persists source paths and failed paths for recovery;
- `ImportBatch` persists its original linked/managed storage mode;
- running batches are persisted before per-file processing begins, enabling restart/crash recovery semantics;
- failed/partial batches can retry only failed paths when available, or all source paths for an interrupted `running` batch;
- retry requires the original Workplace;
- retry preserves the original batch storage mode;
- successful assets from a previous attempt remain protected by source-path duplicate detection;
- Studio import UI exposes failed-import status and a retry action.

Backward compatibility:

- older persisted `ImportBatch` records without `sourcePaths`, `failedPaths`, or `storageMode` remain readable;
- legacy batches default to empty recovery paths and linked storage semantics.

## W4-B remaining after managed/import recovery

Still required before W4 is complete:

- thumbnail generation/cache hardening;
- corrupt/missing thumbnail recovery;
- bounded thumbnail memory/filesystem pressure;
- representative large-catalog profiling and measurements;
- additional desktop/manual external-volume recovery gates.

Do not claim W4 complete until these remaining items are implemented or explicitly moved to a later documented milestone.

## W4 guardrails

- catalog removal and physical deletion are separate operations;
- linked originals are never silently moved or deleted;
- missing/disconnected linked assets stay cataloged;
- a missing managed mount/root must not be silently recreated at the same path;
- managed copy must not overwrite an existing file;
- failed catalog writes must not leave newly copied managed originals orphaned;
- import retry must preserve catalog identity/duplicate safety and original storage semantics;
- no synchronous filesystem checks per Grid tile;
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

## Documentation map

```text
docs/PROJECT_HANDOFF.md                    canonical project status / execution queue
docs/CODE_WALKTHROUGH.md                   current code ownership and data flow
docs/W4_DESKTOP_CATALOG_HARDENING.md       W4 implementation, recovery semantics and acceptance gates
```

## Future — PixelCraft external-editor integration

Only after catalog workflows stabilize. Dextryx Images remains catalog authority; PixelCraft remains processing authority. Future integration should exchange stable asset/edit references rather than duplicate processing internals.

## Immediate execution order

```text
DONE      W4-A PR #12 missing/relink/catalog-removal hardening
CURRENT   W4-B managed destination/copy + import-batch recovery
NEXT      W4-B thumbnail/cache hardening + large-catalog profiling
FUTURE    PixelCraft external-editor contract
```
