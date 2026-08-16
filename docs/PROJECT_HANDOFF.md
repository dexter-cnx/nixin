# Dextryx Images — Project Handoff

> Canonical current status and execution queue for `dexter-cnx/nixin`.

## Current status

- Product: **Dextryx Images**
- Compact app label: **Dxtr Imgs**
- Canonical application/bundle ID: `com.cnxdev.dextryx.images`
- Repository remains `dexter-cnx/nixin`
- Studio workspace UI-01 through UI-15: complete
- **PR #7 / W1 Workplace Core foundation: merged**
- PR #7 merge commit: `befae8ea3976d5d6191df13e59578f80c7ac955f`
- Current milestone: **W2 — Import System + live application wiring**
- Real RAW demosaic/debayer remains deferred.

## Critical implementation truth

W1 implemented the Workplace domain/controller/persistence foundation, but the live application does **not** yet consume it.

Current live startup is:

```text
main.dart
  → ProviderScope
  → NixinApp
  → StudioPage
```

`NixinApp` does not currently watch `workplaceControllerProvider`, and the live Studio tree does not otherwise instantiate it. Because Riverpod providers are lazy, `WorkplaceController.initialize()` is not automatically executed by a normal app launch today.

Therefore W1 delivered these as implemented/tested capabilities, not yet reachable end-user behavior:

```text
Workplace/Asset domain models
Hive repositories
WorkplaceController / WorkplaceState
create default "My workplace" logic
restore current Workplace logic
create / switch / rename / delete commands
last-Workplace invariant
catalog-only asset cleanup semantics
```

W2 must first close this wiring gap before treating Workplaces as application authority.

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

Image-processing/editor work belongs to PixelCraft / Dextryx Pixels. Do not copy PixelCraft UX or processing milestones into this repository.

Stable PixelCraft packages/modules may be reused only through explicit reusable boundaries. Do not couple Dextryx Images to PixelCraft application state or UI internals.

Future full **Open/Edit in PixelCraft** integration is a separate cross-product contract and is not part of the current Workplaces phase.

## Canonical documents

| Document | Role |
|---|---|
| `docs/PROJECT_HANDOFF.md` | Current status and execution queue |
| `docs/WORKPLACES_HANDOFF.md` | Detailed Workplaces/import/catalog specification |
| `docs/CODE_WALKTHROUGH.md` | Current code orientation and wiring state |
| `docs/DEXTRYX_IDENTITY.md` | Product naming and identifier rules |
| `docs/DEXTRYX_IMAGES_HANDOFF.md` | Identity migration record |
| `docs/STUDIO_WORKSPACE_HANDOFF.md` | Completed studio milestone history |

`PROJECT_HANDOFF.md` is the source of truth for what to do next. Supporting documents must not introduce a competing current roadmap.

## Completed — W1 Workplace Core foundation / PR #7

Merged into `main` on 2026-08-16.

Merge commit:

```text
befae8ea3976d5d6191df13e59578f80c7ac955f
```

Delivered in code:

- `Workplace` domain model
- `AssetRecord` catalog model
- repository interfaces
- Hive-backed Workplace persistence
- Hive-backed Asset persistence
- `WorkplaceController` / `WorkplaceState`
- default `My workplace` initialization logic
- current Workplace persistence/restoration logic
- create / switch / rename / delete commands
- invariant that at least one Workplace must remain
- catalog-only asset removal when a Workplace is deleted
- user-facing Library → Workplaces terminology groundwork
- Dextryx Images identity migration
- explicit Dextryx Images ↔ PixelCraft ownership boundary

Not yet delivered as live application behavior:

- app startup consuming `workplaceControllerProvider`
- real fresh-launch creation of `My workplace`
- visible Workplace CRUD/switching UI driven by controller state
- Studio selection driven by the active Workplace/catalog

Validation at W1 merge:

```text
flutter analyze  PASS
flutter test     PASS
cargo check      PASS
cargo test       PASS
```

## Current — W2 Import System + live application wiring

Recommended implementation branch:

```text
feature/workplaces-import
```

### W2.0 — Wire Workplace foundation into the live app

Do this first:

- consume `workplaceControllerProvider` from the live application/workspace
- initialize Workplace state during a real app session
- verify fresh launch creates `My workplace`
- expose current Workplace context in UI/state
- make create / switch / rename / delete reachable where appropriate
- keep existing Studio behavior working while Workplace state becomes application context
- add widget/integration coverage proving the provider is actually mounted and initialized

Acceptance for W2.0:

- clean app data + launch creates/persists `My workplace`
- restart restores current Workplace
- live UI can observe current Workplace state
- Workplace CRUD is no longer test-only/controller-only behavior

### W2.1 — Durable Import System

Then implement the import pipeline defined by `docs/WORKPLACES_HANDOFF.md`:

- `Import` as catalog entry command
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

Acceptance for full W2:

- Workplace state is live and durable in the actual application
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
10. Do not document controller/test capability as live product behavior until the app actually wires and exercises it.
11. Keep unrelated project artifacts and roadmaps out of this repository.

## Immediate execution order

```text
CURRENT  W2.0 Live Workplace wiring
THEN     W2.1 Import System
NEXT     W3 Workplace Browser + Filmstrip
THEN     W4 Desktop Catalog Hardening
FUTURE   PixelCraft external-editor contract
```

At every merged PR:

1. update this file with the merged PR number and commit;
2. mark exactly one next milestone as Current;
3. create the next implementation branch from updated `main`;
4. keep detailed specifications in supporting docs without creating a competing roadmap;
5. verify that documented product behavior is actually reachable from the live app;
6. verify that unrelated PixelCraft milestones have not leaked into this project.
