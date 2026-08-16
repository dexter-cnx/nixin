# Dextryx Workplaces — Project Handoff

> Status: This is the canonical next-phase plan after the studio workspace milestone and Dextryx identity rename. The next implementation focus is **Workplaces and asset/catalog management**. Real RAW development, demosaic/debayer, camera color science, and other new image-processing work are explicitly deferred.

## 1. Phase Objective

Build a durable photo/catalog workflow around the existing editor so Dextryx can import, organize, select, and reopen image/RAW assets before further image-processing work begins.

The product term **Workplaces** replaces the user-facing Library concept.

Initial user flow:

```text
Import
  ↓
Workplaces
  ↓
Select asset(s)
  ↓
Develop
  ↓
Export
```

The default workspace is created automatically:

```text
My workplace
```

A Workplace is a logical catalog/container. It is **not** required to map 1:1 to a physical folder on disk.

## 2. Scope Decision

### In scope

- Workplaces domain model and persistence
- default `My workplace`
- create / rename / switch / delete Workplaces
- remember last active Workplace
- rename the user-facing Library module to Workplaces
- replace Open Image / Open RAW entry flow with Import
- multi-file import
- folder import
- recursive folder discovery
- supported image/RAW filtering
- import batches and progress
- duplicate detection
- linked/add mode
- desktop copy/managed-storage mode
- asset catalog persistence
- grid/browser foundation
- filmstrip integration
- thumbnail/preview cache foundation
- missing-file state
- desktop catalog hardening

### Explicitly deferred

Do not introduce new image-processing features in this phase:

- sensor RAW decode
- demosaic/debayer
- linear RAW pipeline
- camera white balance/color matrices
- camera profiles
- new tone/color processing
- GPU processing pipeline changes

Existing RAW embedded-preview behavior and existing raster decode paths may be reused only to supply thumbnails/previews and current Develop behavior.

## 3. Product Terminology

User-facing modules should converge on:

```text
Workplaces | Develop | Export
```

Use **Workplace** for logical asset groups.

Use **Import** instead of Open RAW/Open Image for bringing assets into the catalog.

Recommended terminology:

```text
Workplace       logical catalog/container
Asset           imported image or RAW record
Source          original file/folder location
Import Batch    one import operation
Linked Asset    file remains in its original location
Managed Asset   Dextryx copied the original into managed storage
Filmstrip       current Workplace asset strip / selection surface
```

Avoid using `Library` in new user-facing UI. Internal legacy names may be migrated incrementally when changing them is low-risk.

## 4. Workplace Domain Model

Minimum model:

```text
Workplace
├── id
├── name
├── createdAt
├── updatedAt
├── isDefault
└── assetCount (derived or cached)
```

Behavior:

- first launch creates `My workplace`
- at least one Workplace must always exist
- current/last Workplace survives restart
- user can create a new Workplace
- user can rename a Workplace
- user can switch Workplaces
- user can delete a Workplace when another Workplace exists
- deleting a Workplace must not silently delete original files

`My workplace` is the initial default name, not a required permanent name.

## 5. Asset Catalog Model

Minimum `AssetRecord` shape:

```text
AssetRecord
├── id
├── workplaceId
├── originalFilename
├── sourcePath
├── managedPath?
├── storageMode
│   ├── linked
│   └── managed
├── mediaType
│   ├── raw
│   └── raster
├── format
├── fileSize
├── importedAt
├── modifiedAt
├── captureDate?
├── thumbnailPath?
├── previewPath?
├── missing
└── importBatchId
```

Keep `sourcePath` and `managedPath` separate.

Future metadata should remain easy to add without schema redesign:

```text
rating
flag
colorLabel
camera
lens
keywords
favorite
```

Do not implement those future features merely because the schema can support them.

## 6. Persistence Architecture

The project already has Hive available. Use it initially behind explicit repository interfaces rather than binding widgets to Hive.

Recommended boundaries:

```text
UI
 ↓
WorkplaceController / ImportController / StudioController
 ↓
WorkplaceRepository
AssetRepository
ImportRepository
 ↓
Hive implementation (initial)
```

This allows later migration to SQLite/Drift or another indexed catalog store if large libraries require richer queries without rewriting UI/domain logic.

Repository contracts should own:

- CRUD
- ordering/querying
- current Workplace persistence
- asset lookup
- import-batch lookup
- duplicate checks
- missing-state updates

Widgets must not read/write Hive directly.

## 7. Import Entry Flow

Replace the current open-file-first workflow with:

```text
Import
├── Select Images…
└── Select Folder…
```

### Select Images

Requirements:

- multi-select
- supported raster/image formats
- supported RAW formats already understood by the current preview path
- import into the current Workplace
- no UI-isolate blocking during large batches

### Select Folder

Requirements:

- choose a directory
- scan supported assets
- recursively include subfolders by default
- expose `Include subfolders` option
- preserve source path information

Recommended result summary before/while import:

```text
137 files found
132 new
5 suspected duplicates
```

## 8. Import Storage Modes

Desktop should support two explicit modes.

### 8.1 Linked / Add

The original file remains where it is.

```text
Original:
/Volumes/Photos/Japan/DSC001.RAF

Dextryx catalog:
reference → /Volumes/Photos/Japan/DSC001.RAF
```

Use cases:

- existing photo archive
- external SSD
- NAS
- large RAW collections

### 8.2 Managed / Copy

Dextryx copies the original to a user-configurable managed-storage destination.

Example preference:

```text
Managed originals location:
~/Pictures/Dextryx/
```

Do not make filesystem layout depend directly on Workplace display names; Workplace rename must not require moving originals.

Recommended managed-storage strategies include stable asset IDs and/or date partitioning, for example:

```text
Dextryx/originals/2026/08/13/<asset-id>-DSC001.RAF
```

The database remains authoritative for logical Workplace membership.

## 9. Import Pipeline

Import must be represented as an asynchronous pipeline rather than a synchronous file-picker callback.

```text
Select source
 ↓
Discover candidate files
 ↓
Filter supported types
 ↓
Normalize/canonicalize paths
 ↓
Check duplicates
 ↓
Copy when managed mode is selected
 ↓
Read basic metadata
 ↓
Create AssetRecord
 ↓
Generate/cache thumbnail or preview
 ↓
Publish asset into current Workplace
```

Import state should support:

```text
idle
scanning
checkingDuplicates
copying
cataloging
generatingPreviews
completed
cancelled
failed
```

UI should expose useful progress, e.g.:

```text
Importing 137 photos
Copying 84 / 137
Building previews 62 / 137
```

Cancellation must stop future work cleanly. Partial imports must remain internally consistent.

## 10. Import Batch

Every import operation should create an `ImportBatch` identity.

Minimum concept:

```text
ImportBatch
├── id
├── workplaceId
├── startedAt
├── completedAt?
├── sourceType
├── sourceRoot?
├── requestedCount
├── importedCount
├── skippedDuplicateCount
├── failedCount
└── status
```

This enables later features such as:

- Previous Import
- import history
- retry failed assets
- undo/remove recent import from catalog

Do not couple `ImportBatch` to physical file deletion.

## 11. Duplicate Detection

Implement baseline duplicate prevention in the import foundation.

First-pass signals:

```text
canonical source path
file size
modified timestamp
```

Future hardening may add content hashes.

Default import UX:

```text
☑ Don't import suspected duplicates
```

Duplicate detection must be scoped carefully so a copied/relocated original can later be reconciled rather than blindly duplicated.

## 12. Grid / Workplace Browser

Workplaces should eventually own the primary asset-browser surface.

Desktop composition target:

```text
┌──────────────────────────────────────────────────────────────┐
│ Dextryx             Workplaces   Develop   Export            │
├────────────────┬─────────────────────────────────────────────┤
│ WORKPLACES     │ My workplace                     Import ▼   │
│                │                                             │
│ My workplace   │ [IMG] [IMG] [IMG] [IMG] [IMG]              │
│ Wedding        │ [IMG] [IMG] [IMG] [IMG] [IMG]              │
│ Japan          │                                             │
│                │                                             │
│ + Workplace    │                                             │
├────────────────┴─────────────────────────────────────────────┤
│ [IMG] [IMG] [IMG] [IMG] [IMG] [IMG]            Filmstrip   │
└──────────────────────────────────────────────────────────────┘
```

Browser foundation should support:

- empty state
- thumbnail grid
- selected state
- asset count
- basic sort order
- responsive columns
- large-list virtualization/lazy building
- missing-asset indicator

Do not add advanced rating/filter/search UI until the catalog core is stable.

## 13. Filmstrip Integration

The Grid and Filmstrip must not maintain independent asset collections or independent selected-asset truth.

Required state relationship:

```text
Current Workplace
       ↓
Asset Query / Ordered Asset List
       ├── Workplace Grid
       └── Filmstrip

selectedAssetId
       ├── Grid highlight
       ├── Filmstrip highlight
       └── Develop current asset
```

Importing assets into the active Workplace should update the Filmstrip automatically.

Selecting a Grid item should select the same item in the Filmstrip.

Selecting the Filmstrip should update the current asset and Grid selection.

The existing Filmstrip implementation should be evolved, not duplicated.

## 14. Preview / Thumbnail Boundary

Workplaces must not depend directly on future RAW processing internals.

Introduce or preserve a preview abstraction such as:

```dart
abstract interface class AssetPreviewProvider {
  Future<Uint8List?> thumbnail(AssetRecord asset);
}
```

During this phase:

- RAW assets may use the existing embedded-preview behavior
- JPEG/PNG/raster assets may use the existing raster decode behavior
- cache generated thumbnails/previews where practical

Future RAW engine changes must be replaceable behind this boundary.

## 15. Missing Files and External Storage

Linked assets can become unavailable when files move or external storage is disconnected.

Catalog behavior:

```text
Asset remains in Workplace
missing = true
preview/thumbnail may remain cached
original-dependent operations are disabled or show recovery UI
```

Future recovery commands:

```text
Locate Missing File…
Locate Missing Folder…
```

Design the model for these now; full relink UX belongs in W4.

## 16. File Removal Semantics

Never make catalog removal and physical deletion ambiguous.

Separate commands conceptually:

```text
Remove from Workplace
```

versus an explicit destructive filesystem action such as:

```text
Move Original to Trash…
```

The first removes catalog membership only.

Physical deletion must never happen implicitly when a Workplace or asset record is removed.

## 17. Application State Integration

The current Workplace becomes top-level application context.

Conceptual state:

```text
currentWorkplaceId
orderedAssets
selectedAssetId
activeModule
```

Develop and Export should consume current catalog selection rather than owning unrelated file-path state.

Transitional adapters are acceptable while migrating current `selectedPath`/single-image assumptions.

Guardrail: do not perform a broad state-management rewrite solely for this phase.

## 18. Suggested Flutter Structure

Exact naming may evolve, but ownership should resemble:

```text
lib/
  workplaces/
    domain/
      workplace.dart
      asset_record.dart
      import_batch.dart
      storage_mode.dart
      repositories/
        workplace_repository.dart
        asset_repository.dart
        import_repository.dart

    data/
      hive/
        hive_workplace_repository.dart
        hive_asset_repository.dart
        hive_import_repository.dart

    application/
      workplace_controller.dart
      import_controller.dart
      import_state.dart
      import_service.dart

    ui/
      workplaces_page.dart
      workplace_sidebar.dart
      workplace_grid.dart
      asset_tile.dart
      import_dialog.dart
      import_progress.dart

  studio/
    filmstrip/
      ... existing Filmstrip evolved to consume catalog state ...
```

Keep file picker and filesystem operations out of leaf widgets.

## 19. Delivery Plan

Implement this phase as four bounded pull requests.

### W1 — Workplace Core

Scope:

- Workplace model
- AssetRecord model
- repository interfaces
- Hive persistence
- schema/version handling
- default `My workplace`
- current Workplace persistence
- create / switch / rename / delete behavior
- user-facing Library → Workplaces rename
- initial application-state integration

Acceptance:

- clean/fresh install creates `My workplace`
- restart restores Workplaces and active Workplace
- create/switch/rename work
- deletion cannot leave zero Workplaces
- original image-processing behavior does not regress
- `flutter analyze` and `flutter test` pass

### W2 — Import System

Scope:

- Import command replaces Open Image/Open RAW as primary entry
- Select Images multi-select
- Select Folder
- recursive scanning
- supported-format filter
- ImportBatch
- asynchronous progress
- cancellation
- baseline duplicate detection
- linked/add mode
- desktop managed/copy mode
- managed destination preference
- safe partial failure behavior

Acceptance:

- import 100+ mixed supported files without freezing UI
- files appear after restart
- duplicate default prevents repeat catalog entries
- linked mode never copies originals
- managed mode copies to configured desktop destination
- failed/cancelled imports leave a consistent catalog

### W3 — Workplace Browser + Filmstrip

Scope:

- Workplace asset grid
- thumbnail/preview provider boundary
- thumbnail cache foundation
- current Workplace asset query
- single selected-asset source of truth
- Grid ↔ Filmstrip selection synchronization
- imported assets automatically appear in Filmstrip
- empty/loading/error browser states
- basic sorting
- missing indicator foundation
- responsive/virtualized browser behavior

Acceptance:

- imported assets are visible in Workplace Grid
- same ordered asset set powers Grid and Filmstrip
- selection stays synchronized
- selecting an asset continues to drive the existing Develop preview
- large batches remain responsive

### W4 — Desktop Catalog Hardening

Scope:

- missing-file detection
- Locate Missing File
- Locate Missing Folder / batch relink
- disconnected external-disk behavior
- managed-storage preference hardening
- copy collision/failure recovery
- import batch recovery
- catalog-only removal
- explicit original deletion path if/when enabled
- large catalog tests and performance profiling

Acceptance:

- disconnected linked assets remain cataloged and identifiable
- relink restores normal operation
- managed assets survive Workplace rename
- filesystem failures do not corrupt catalog state
- catalog removal does not delete originals
- representative large catalog remains usable

## 20. Test Strategy

### Unit

- Workplace invariants
- default Workplace initialization
- repository CRUD
- current Workplace persistence
- duplicate rules
- storage-mode decisions
- import-batch state transitions
- path normalization

### Widget

- first-launch Workplace state
- create/rename/switch UI
- Import dialog modes
- import progress/cancel
- Grid empty/populated states
- Grid/Filmstrip synchronized selection
- missing-file visual state

### Integration

- multi-file import → restart → records restored
- recursive folder import
- duplicate re-import
- linked external source
- managed copy import
- asset selection → existing Develop flow

### Desktop manual gate

- launch
- `My workplace` initialization
- multi-select import
- folder import with nested directories
- import progress remains responsive
- linked import from external storage
- managed copy destination
- restart/reopen
- Filmstrip population and selection
- existing RAW embedded preview
- PNG/JPEG preview
- Subject/Sky masks
- LUT
- JPEG export

Any existing processing regression blocks merging a Workplaces PR even though this phase does not add image-processing behavior.

## 21. Performance Targets / Guardrails

Do not hard-code unrealistic absolute performance promises before profiling, but design for:

- asynchronous directory scanning
- bounded concurrency
- lazy thumbnail generation
- thumbnail caching
- lazy/virtualized Grid and Filmstrip construction
- no full-size image decode merely to render a small catalog thumbnail when a cheaper preview path exists
- cancellation and stale-result rejection where async selection/import work can race

Test at increasing scales such as 100, 1,000, and 10,000 catalog records even if test fixtures use synthetic metadata.

## 22. Phase Guardrails

1. Do not start new RAW/image-processing work during W1–W4.
2. Preserve current Rust/FFI behavior.
3. Workplaces are logical catalogs, not aliases for folders.
4. UI never persists directly to Hive.
5. Grid and Filmstrip share the same asset source and selected-asset truth.
6. Linked and managed storage are explicit and distinguishable.
7. Removing catalog data must not silently delete originals.
8. Import must remain responsive and cancellable.
9. Do not duplicate file-picker/filesystem logic across widgets.
10. Thumbnail generation is behind an abstraction so the future RAW engine can replace its implementation.
11. Do not expose unsupported metadata/edit features merely to imitate another application.
12. Existing Develop/Mask/LUT/Export behavior remains a regression gate.

## 23. Branch / PR Workflow

Current implementation branch:

```text
feature/workplaces-foundation
```

The previously created RAW-foundation branch is obsolete for current planning; no Workplaces implementation should be committed there.

Recommended PR sequence:

```text
PR W1  Workplace Core
PR W2  Import System
PR W3  Workplace Browser + Filmstrip
PR W4  Desktop Catalog Hardening
```

Prefer new branches from updated `main` for each PR after the previous PR is merged, rather than carrying all W1–W4 commits on one long-lived branch.

## 24. Definition of Phase Complete

The Workplaces phase is complete when a user can:

1. launch Dextryx and receive a persistent `My workplace`
2. create and switch Workplaces
3. import multiple images/RAWs
4. import an entire folder tree
5. choose linked or managed-copy behavior on desktop
6. restart Dextryx without losing the catalog
7. browse imported assets in a Workplace Grid
8. see the same assets in the bottom Filmstrip
9. select from Grid or Filmstrip and continue into the existing Develop flow
10. identify and relink missing linked files
11. remove catalog membership without unexpectedly deleting originals
12. complete all of the above without introducing a new RAW-processing pipeline

After this phase is stable, Dextryx can proceed to later catalog features (collections, ratings, flags, search/filter, history) or resume deferred RAW/image-processing milestones based on product priority.
