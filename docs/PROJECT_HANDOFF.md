# Dextryx Images — Project Handoff

> Canonical current status and execution queue for `dexter-cnx/nixin`.

## Current status

- Product: **Dextryx Images**
- Compact app label: **Dxtr Imgs**
- Canonical application/bundle ID: `com.cnxdev.dextryx.images`
- Repository remains `dexter-cnx/nixin`
- Studio workspace UI-01 through UI-15: complete
- **PR #7 / W1 Workplace Core: merged**
- PR #7 merge commit: `befae8ea3976d5d6191df13e59578f80c7ac955f`
- Current milestone: **W2 — Import System**
- Real RAW demosaic/debayer remains deferred.

## Product responsibility

Dextryx Images is currently the **image/catalog management application**.

It owns:

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

Image-processing/editor work belongs to PixelCraft / Dextryx Pixels. Do not copy PixelCraft UX or processing milestones into this repository.

Stable PixelCraft packages/modules may be reused only through explicit reusable boundaries. Do not couple Dextryx Images to PixelCraft application state or UI internals.

Future full **Open/Edit in PixelCraft** integration is a separate cross-product contract and is not part of the current Workplaces phase.

## Canonical documents

| Document | Role |
|---|---|
| `docs/PROJECT_HANDOFF.md` | Current status and execution queue |
| `docs/WORKPLACES_HANDOFF.md` | Detailed Workplaces/import/catalog specification |
| `docs/CODE_WALKTHROUGH.md` | Current code orientation and ownership boundaries |
| `docs/DEXTRYX_IDENTITY.md` | Product naming and identifier rules |
| `docs/DEXTRYX_IMAGES_HANDOFF.md` | Identity migration record |
| `docs/STUDIO_WORKSPACE_HANDOFF.md` | Completed studio milestone history |

`PROJECT_HANDOFF.md` is the source of truth for what to do next. Supporting documents may describe completed history or detailed design, but must not introduce a competing current roadmap.

## Completed — W1 Workplace Core / PR #7

Merged into `main` on 2026-08-16.

Merge commit:

```text
befae8ea3976d5d6191df13e59578f80c7ac955f
```

Delivered:

- `Workplace` domain model
- `AssetRecord` catalog model
- repository interfaces
- Hive-backed Workplace persistence
- Hive-backed Asset persistence
- automatic `My workplace`
- current Workplace persistence/restoration
- create / switch / rename / delete behavior
- invariant that at least one Workplace must remain
- catalog-only asset removal when a Workplace is deleted
- user-facing Library → Workplaces terminology
- Dextryx Images identity migration
- explicit Dextryx Images ↔ PixelCraft ownership boundary

Validation at merge:

```text
flutter analyze  PASS
flutter test     PASS
cargo check      PASS
cargo test       PASS
```

## Current — W2 Import System

Recommended implementation branch:

```text
feature/workplaces-import
```

Goal: replace the legacy single-file Open Image/Open RAW entry path with a durable catalog import system defined by `docs/WORKPLACES_HANDOFF.md`.

Scope:

- `Import` becomes the catalog entry command
- Select Images with multi-select
- Select Folder
- recursive folder discovery
- supported raster/RAW filtering
- `ImportBatch`
- asynchronous scanning/import progress
- cancellation
- baseline duplicate detection
- linked/add mode
- desktop managed/copy mode
- managed destination preference
- safe partial-failure behavior
- imported assets persist in the active Workplace
- preserve existing preview/Develop compatibility

Acceptance:

- 100+ mixed supported assets can be imported without blocking the UI
- imported catalog records survive restart
- duplicate prevention blocks obvious repeat catalog entries by default
- linked mode never copies originals
- managed mode copies originals to the configured desktop destination
- failed or cancelled imports leave a consistent catalog
- current embedded RAW preview, raster preview, masks, LUT, and JPEG export do not regress
- `flutter analyze`, `flutter test`, `cargo check`, and `cargo test` pass

## Next — W3 Workplace Browser + Filmstrip

Recommended branch:

```text
feature/workplaces-browser
```

Scope:

- Workplace asset grid
- empty/loading/error states
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

Acceptance:

- imported assets are visible in the Workplace Grid
- Grid and Filmstrip consume the same ordered asset collection
- Grid, Filmstrip, and Develop stay synchronized on selection
- large batches remain responsive

## Then — W4 Desktop Catalog Hardening

Recommended branch:

```text
feature/workplaces-hardening
```

Scope:

- missing-file detection
- Locate Missing File
- Locate Missing Folder / batch relink
- disconnected external-storage behavior
- managed-storage recovery
- copy collision/failure recovery
- import-batch recovery
- catalog-only removal semantics
- explicit original-deletion path only if intentionally enabled later
- large-catalog profiling and performance hardening
- desktop keyboard/context-menu polish where useful

Catalog removal and physical deletion must remain separate operations.

## Future — PixelCraft external-editor integration

Only after Workplaces/catalog flows are stable and after an explicit cross-product design.

Design first:

```text
launch/deep-link/IPC mechanism
asset/source handoff contract
security/path-access model
edit-session identity
recipe/result return contract
version negotiation
cancel/failure behavior
derivative ownership
catalog refresh after return
```

Dextryx Images remains catalog authority; PixelCraft remains editing/processing authority.

## Guardrails

1. Do not start real RAW demosaic/debayer during W2–W4.
2. Do not move PixelCraft UX modernization or processing roadmap into this repository.
3. Reuse PixelCraft code only through stable reusable package/module APIs.
4. Do not couple Dextryx Images to PixelCraft application state or UI internals.
5. Preserve current Develop/Mask/LUT/Export behavior as a regression gate.
6. Workplaces are logical catalogs, not aliases for physical folders.
7. Catalog removal must never silently delete originals.
8. Import must remain asynchronous, responsive, and cancellable.
9. Grid and Filmstrip must eventually share one ordered asset source and one selected-asset truth.
10. Keep unrelated project artifacts and roadmaps out of this repository.

## Immediate execution order

```text
CURRENT  W2 Import System
NEXT     W3 Workplace Browser + Filmstrip
THEN     W4 Desktop Catalog Hardening
FUTURE   PixelCraft external-editor contract
```

At every merged PR:

1. update this file with the merged PR number and commit;
2. mark exactly one next milestone as Current;
3. create the next implementation branch from updated `main`;
4. keep detailed specifications in supporting docs without creating a competing roadmap;
5. verify that unrelated PixelCraft milestones have not leaked into this project.
