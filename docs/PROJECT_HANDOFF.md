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
- Current implementation branch: `feature/workplaces-import-ux`
- Current milestone: **UX-01 / W2A — Import Simplification**
- Real RAW demosaic/debayer remains deferred.

## Product boundary

### Nixin / Dextryx Images

Primary responsibility: **image management / catalog / Workplaces**.

Nixin owns:

```text
Workplaces
asset catalog identity
import / folder discovery
linked vs managed storage
asset organization
thumbnail/preview browsing
grid / filmstrip selection
missing / relink workflows
catalog metadata
large-library UX
external-edit orchestration
```

### PixelCraft / Dextryx Pixels

Primary responsibility: **photo editing / image processing**.

PixelCraft owns:

```text
edit-session UX
image-processing semantics
adjustments / masks / transforms
GPU preview
render / export
recipe/history/checkpoint authority
```

Nixin may reuse stable PixelCraft packages/modules only through explicit reusable boundaries. Do not couple Nixin to PixelCraft app internals or copy PixelCraft's roadmap into this repository.

Future full **Open/Edit in PixelCraft** integration is a separate cross-product contract and is not part of the current Workplaces phase.

## Canonical documents

| Document | Role |
|---|---|
| `docs/PROJECT_HANDOFF.md` | Current status and execution queue |
| `docs/WORKPLACES_HANDOFF.md` | Detailed Workplaces/import/catalog specification |
| `docs/DEXTRYX_IDENTITY.md` | Product naming and identifier rules |
| `docs/DEXTRYX_IMAGES_HANDOFF.md` | Identity migration record |
| `docs/STUDIO_WORKSPACE_HANDOFF.md` | Completed studio milestone history |
| `docs/CODE_WALKTHROUGH.md` | Code orientation/reference |

Keep unrelated repository/package roadmaps out of this handoff.

## Completed — W1 Workplace Core / PR #7

Merged into `main` on 2026-08-16.

Merge commit:

```text
befae8ea3976d5d6191df13e59578f80c7ac955f
```

Delivered:

- `Workplace` domain model
- `AssetRecord` catalog model
- repository contracts
- Hive-backed Workplace/Asset persistence
- automatic `My workplace`
- active Workplace persistence/restoration
- create / switch / rename / delete behavior
- last-Workplace invariant
- catalog-only removal semantics
- Library → Workplaces terminology
- final Dextryx Images identity migration
- Nixin ↔ PixelCraft ownership boundary

Validation at merge:

```text
flutter analyze  PASS
flutter test     PASS
cargo check      PASS
cargo test       PASS
```

## Current — UX-01 / W2A Import Simplification

Branch:

```text
feature/workplaces-import-ux
```

Goal: replace the current test-app-style asset-entry flow with one obvious modern Import action.

Implement:

- primary action is **Import**
- normal Import opens multi-select image/file picker directly
- folder import becomes a secondary action/menu
- desktop copy/reference choice is an option, not three peer actions
- remember previous/default storage behavior
- modern empty Workplace state
- desktop drag/drop affordance
- unobtrusive progress/status presentation
- no success modal after normal completion
- preserve W1 persistence and current Develop compatibility

UX rule:

> Ask what the user wants to import, not how the internal storage implementation works.

Acceptance:

- common photo import has one obvious primary action
- secondary import modes remain discoverable
- no three-choice blocking dialog on the normal path
- W1 Workplace persistence remains intact
- current image-processing behavior does not regress
- no new image-processing scope is introduced
- `flutter analyze` and `flutter test` pass

## Next — W2B Import Pipeline + Review

Recommended branch after W2A merges:

```text
feature/workplaces-import-pipeline
```

Implement from `docs/WORKPLACES_HANDOFF.md`:

- multi-file import pipeline
- folder import / recursive discovery
- supported-format filtering
- `ImportBatch`
- async progress and cancellation
- duplicate detection
- linked/add mode
- desktop managed/copy mode
- managed destination preference
- safe partial-failure semantics
- compact Import Review only when useful

Acceptance target: 100+ supported mixed assets import without freezing the UI and persist correctly across restart.

## Then — W3 Workplace Browser + Filmstrip

Recommended branch:

```text
feature/workplaces-browser
```

Implement:

- Workplace asset grid
- empty/loading/error states
- thumbnail/preview provider boundary
- thumbnail cache foundation
- lazy/virtualized grid
- one selected-asset source of truth
- Grid ↔ Filmstrip synchronization
- automatic filmstrip updates after import
- basic sorting
- missing-asset indicator foundation

## Then — W4 Desktop Catalog Hardening

Recommended branch:

```text
feature/workplaces-hardening
```

Implement:

- missing-file detection
- relink file/folder workflows
- disconnected external-storage behavior
- managed-storage recovery
- import-batch recovery
- catalog-only removal semantics
- large-catalog profiling
- keyboard/context-menu polish

Catalog removal and physical deletion must remain separate actions.

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

Nixin remains catalog authority; PixelCraft remains editing/processing authority.

## Guardrails

1. Do not start real RAW demosaic/debayer during W2–W4.
2. Do not move PixelCraft's processing roadmap into Nixin.
3. Reuse PixelCraft code only through stable reusable package/module APIs.
4. Do not couple Nixin to PixelCraft application state or UI internals.
5. Preserve current Develop/Mask/LUT/Export behavior as a regression gate.
6. Workplaces are logical catalogs, not aliases for physical folders.
7. Catalog removal must never silently delete originals.
8. Import must remain responsive and cancellable when the durable pipeline lands.
9. Grid and Filmstrip must eventually share one ordered asset source and one selected-asset truth.
10. Keep unrelated project artifacts out of this repository.

## Immediate execution order

```text
CURRENT  UX-01 / W2A Import Simplification
NEXT     W2B Import Pipeline + Review
THEN     W3 Workplace Browser + Filmstrip
THEN     W4 Desktop Catalog Hardening
FUTURE   PixelCraft external-editor contract
```

At every merged PR:

1. update this file with merge PR/commit;
2. mark exactly one next milestone as Current;
3. create the next branch from updated `main`;
4. keep supporting specs detailed but avoid competing top-level handoffs;
5. re-check that no unrelated project roadmap or artifact has been mixed into Nixin.
