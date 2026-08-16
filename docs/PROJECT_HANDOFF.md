# Dextryx Images — Project Handoff

> Canonical current status and execution queue for `dexter-cnx/nixin`.

## Current status

- Product: **Dextryx Images**
- Compact app label: **Dxtr Imgs**
- Canonical application/bundle ID: `com.cnxdev.dextryx.images`
- Repository remains `dexter-cnx/nixin`
- Studio workspace UI-01 through UI-15: complete
- **PR #7 / W1 Workplace Core foundation: merged**
- **PR #9 / documentation realignment: merged**
- Current implementation branch: `feature/workplaces-import`
- Current milestone: **W2 — Import System + live Workplace wiring**
- Real RAW demosaic/debayer remains deferred.

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

PixelCraft / Dextryx Pixels owns editing and image-processing semantics. Do not copy PixelCraft UX or processing milestones into this repository.

## Completed — W1 Workplace Core foundation

Delivered domain/controller/persistence foundations:

- `Workplace`
- `AssetRecord`
- `WorkplaceRepository`
- `AssetRepository`
- Hive-backed persistence
- `WorkplaceController`
- default `My workplace` initialization logic
- current Workplace persistence/restoration
- create / switch / rename / delete commands
- invariant that at least one Workplace remains
- catalog-only removal semantics

W1 did not wire `workplaceControllerProvider` into the live Studio tree; W2 closes that gap.

## Current — W2 Import System + live Workplace wiring

Branch:

```text
feature/workplaces-import
```

Implementation target:

- consume `workplaceControllerProvider` from live Studio UI
- expose current Workplace switch/create/rename/delete controls
- initialize `My workplace` on a real fresh launch
- primary multi-select Import
- secondary folder import
- recursive discovery by default with current-folder-only option
- supported raster/RAW filtering
- `ImportBatch` persistence
- async progress and cancellation
- baseline duplicate detection by normalized source path within active Workplace
- linked/add mode
- desktop managed/copy mode
- remembered managed destination and storage mode
- safe partial-failure accounting
- persist imported assets to active Workplace
- hand latest imported asset to existing Studio preview/Develop compatibility path

Regression gates:

- embedded RAW preview remains functional
- raster preview remains functional
- Develop/Mask/LUT/JPEG export behavior does not regress
- no new image-processing scope
- `flutter analyze`, `flutter test`, `cargo check`, and `cargo test` pass

## Next — W3 Workplace Browser + Filmstrip

- Workplace asset grid
- thumbnail/preview provider boundary
- thumbnail cache foundation
- current Workplace asset query
- lazy/virtualized grid
- one ordered asset source of truth
- one selected-asset source of truth
- Grid ↔ Filmstrip synchronization
- automatic Filmstrip updates after import
- basic sorting
- missing-asset indicator foundation

## Then — W4 Desktop Catalog Hardening

- missing-file detection
- Locate Missing File / Folder
- disconnected external-storage behavior
- managed-storage recovery
- copy/import failure recovery
- import-batch recovery
- catalog-only removal semantics
- large-catalog profiling and performance hardening

Catalog removal and physical deletion must remain separate operations.

## Future — PixelCraft external-editor integration

Only after Workplaces/catalog flows stabilize. Dextryx Images remains catalog authority; PixelCraft remains processing authority.

## Immediate execution order

```text
CURRENT  W2 Import System + live Workplace wiring
NEXT     W3 Workplace Browser + Filmstrip
THEN     W4 Desktop Catalog Hardening
FUTURE   PixelCraft external-editor contract
```
