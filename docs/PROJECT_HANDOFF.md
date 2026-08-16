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
- **W3 Workplace Browser + Filmstrip: implementation complete in PR #11**
- Current implementation branch: `feature/workplace-browser-filmstrip`
- Next milestone after merge: **W4 — Desktop Catalog Hardening**
- Real RAW demosaic/debayer and other new image-processing work remain deferred.

## Product responsibility

Dextryx Images owns image/catalog management:

```text
Workplaces
asset catalog identity
import and folder discovery
linked vs managed storage
asset organization
thumbnail/preview browsing
grid and filmstrip selection
missing/relink workflows
catalog metadata
large-library UX
external-edit orchestration
```

PixelCraft / Dextryx Pixels owns editing and image-processing semantics. Keep its processing roadmap separate from this repository.

## Completed — W1 Workplace Core

Delivered:

- `Workplace` and `AssetRecord`
- repository contracts with Hive-backed persistence
- default `My workplace`
- active Workplace persistence/restoration
- create / switch / rename / delete behavior
- invariant that at least one Workplace remains
- catalog-only Workplace removal semantics

## Completed — W2 Import System + live wiring

Delivered:

- live `workplaceControllerProvider` wiring
- active Workplace controls in Studio
- primary multi-select Import
- recursive folder import plus current-folder-only option
- supported raster/RAW filtering
- `ImportBatch` persistence
- async progress and cancellation
- baseline duplicate detection
- linked/add mode
- desktop managed/copy mode
- remembered managed destination/storage mode
- partial-failure accounting
- imported assets persisted to the active Workplace
- compatibility handoff to existing Studio Develop preview

## W3 — Workplace Browser + Filmstrip

PR #11 delivers:

- `AssetBrowserController` as owner of active Workplace ordered assets
- one `selectedAssetId` source of truth
- active-Workplace asset querying and refresh after import
- responsive lazy Workplace Grid
- loading / empty / error states
- basic sorting: import order, recent-first, filename
- missing-asset indicator foundation
- `AssetPreviewProvider` boundary
- Filmstrip evolved to consume the same catalog list and selection state as Grid
- Grid ↔ Filmstrip selection synchronization
- selected asset handoff to the existing Develop path
- post-import browser selection synchronization
- stale assets cleared when Workplace switching/querying fails

Review hardening for PR #11 specifically closes two state-consistency risks:

1. assets from the previous Workplace cannot remain actionable after a failed switch/query;
2. post-import Develop selection also updates catalog `selectedAssetId`, so Grid, Filmstrip and Develop remain aligned.

W3 intentionally does **not** add sensor RAW decoding, demosaic/debayer, PixelCraft processing, advanced rating/search/filter UX, or full missing-file relink behavior.

## Next — W4 Desktop Catalog Hardening

Scope:

- missing-file detection
- Locate Missing File
- Locate Missing Folder / batch relink
- disconnected external-storage behavior
- managed-storage preference/recovery hardening
- copy collision and filesystem failure recovery
- import-batch recovery
- catalog-only asset removal
- explicit original deletion path only if intentionally enabled later
- thumbnail cache/generation hardening where required by real catalog use
- large-catalog profiling and performance hardening

Guardrails:

- catalog removal and physical deletion remain separate operations
- linked originals are never silently moved/deleted
- Workplace rename must not move managed originals
- no broad state-management rewrite solely for W4
- no new RAW/image-processing scope

## Regression gates

Every Workplaces/catalog PR must preserve:

- existing embedded RAW preview behavior
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

Only after catalog workflows stabilize. Dextryx Images remains catalog authority; PixelCraft remains processing authority. A future integration should exchange stable asset/edit references rather than duplicate processing internals.

## Immediate execution order

```text
FINALIZE  W3 Workplace Browser + Filmstrip (PR #11)
NEXT      W4 Desktop Catalog Hardening
FUTURE    PixelCraft external-editor contract
```
