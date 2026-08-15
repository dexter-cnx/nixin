# Dextryx Images — Project Handoff

> Canonical status and execution queue for this repository. This file decides what gets worked on next and in what order.

## Current repository state

- Product name: **Dextryx Images**
- Compact app label: **Dxtr Imgs**
- Canonical application/bundle ID: `com.cnxdev.dextryx.images`
- Repository remains `dexter-cnx/nixin`
- Existing studio workspace milestone UI-01 through UI-15 is complete.
- Current active implementation branch: `feature/workplaces-foundation`
- Current open PR: **PR #7 — Workplace Core + product identity**
- Real RAW development / demosaic / debayer remains deferred.
- New image-processing features must not derail Workplaces/catalog UX work.

## Canonical document map

| Document | Role |
|---|---|
| `docs/PROJECT_HANDOFF.md` | Canonical current status and execution order |
| `docs/WORKPLACES_HANDOFF.md` | Detailed Workplaces/catalog/import specification |
| `docs/DEXTRYX_IDENTITY.md` | Canonical product naming and identifier rules |
| `docs/DEXTRYX_IMAGES_HANDOFF.md` | Identity migration record/checklist |
| `docs/STUDIO_WORKSPACE_HANDOFF.md` | Historical/completed studio workspace milestone |
| `docs/CODE_WALKTHROUGH.md` | Code orientation/reference |

Do not place plans for unrelated packages or repositories in this handoff. Separate projects must keep their own handoff and roadmap.

## Product priority

```text
Workplace core
    ↓
Modern import UX
    ↓
Import pipeline
    ↓
Workplace browser / filmstrip integration
    ↓
Desktop catalog hardening
    ↓
Advanced Develop / real RAW pipeline (deferred)
```

The normal photo-management path should stay short:

```text
Launch
  ↓
My workplace
  ↓
Import
  ↓
Select photos/folder
  ↓
Assets appear in Workplace
  ↓
Select / double-click
  ↓
Develop
```

## PR policy

Keep one implementation purpose per PR. Future implementation must not be mixed into the current PR.

### Current — PR #7 / W1 Workplace Core

Branch: `feature/workplaces-foundation`

Purpose:

- Workplace / AssetRecord domain and persistence foundation
- default `My workplace`
- create / switch / rename / delete Workplace behavior
- active Workplace persistence
- Library → Workplaces user-facing terminology
- final Dextryx Images identity migration
- handoff consolidation

Explicitly excluded:

- W2 import implementation
- Workplace grid/browser beyond W1 needs
- unrelated package/plugin work
- real RAW development
- new image-processing behavior

Merge gate:

```text
flutter analyze
flutter test
cargo check
cargo test
native identity validation where applicable
```

After PR #7 is green, merge it before starting the next implementation PR.

## Execution queue

### Queue 1 — UX-01 / W2A: Import Simplification

Create from updated `main` after PR #7 merges.

Recommended branch:

```text
feature/workplaces-import-ux
```

Implement:

- primary action is **Import**
- normal Import opens multi-select image/file picker directly
- folder import is a secondary action
- desktop copy/reference choice is an option, not three peer entry actions
- remember the previous/default storage behavior
- modern empty Workplace state
- desktop drag/drop affordance
- unobtrusive progress/status presentation
- no success modal after normal completion

Acceptance:

- adding common photos is one obvious primary action
- secondary import modes remain discoverable
- W1 persistence remains intact
- no new image processing

### Queue 2 — W2B: Import Pipeline + Review

Recommended branch:

```text
feature/workplaces-import-pipeline
```

Implement from `docs/WORKPLACES_HANDOFF.md`:

- multi-file import
- folder import and recursive discovery
- supported-format filtering
- ImportBatch
- async progress and cancellation
- duplicate detection
- linked/add mode
- desktop managed/copy mode
- managed destination preference
- safe partial-failure semantics
- compact Import Review only when useful

Acceptance:

- 100+ supported mixed assets import without freezing the UI
- restart restores imported records
- duplicate handling is predictable
- linked mode does not copy originals
- managed mode copies only when selected/configured
- cancelled/failed imports leave a consistent catalog

### Queue 3 — W3: Workplace Browser + Filmstrip

Recommended branch:

```text
feature/workplaces-browser
```

Implement:

- Workplace asset grid
- polished empty/loading/error states
- thumbnail/preview provider boundary
- thumbnail cache foundation
- lazy/virtualized grid
- one selected-asset source of truth
- Grid ↔ Filmstrip synchronization
- imported assets automatically appear in Filmstrip
- basic sorting
- missing-asset indicator foundation
- desktop selection conventions

Desktop target:

```text
single click      select
Ctrl/Cmd click    multi-select where supported
Shift click       range selection where supported
double-click      open selected asset in Develop
```

### Queue 4 — UX-05 / W4: Desktop Catalog Hardening + Polish

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
- large catalog profiling
- keyboard/context-menu polish
- contextual toolbar behavior
- restrained transitions/progress feedback

Guardrail: catalog removal and physical deletion remain distinct actions.

### Queue 5 — Advanced Develop / real RAW pipeline

Still deferred until the Workplaces/catalog workflow is stable.

Future scope may include:

- sensor RAW decode
- demosaic/debayer
- linear working pipeline
- camera white balance
- camera matrices/profiles
- expanded tone/color tools
- GPU processing pipeline decisions

Do not pull this work forward merely because a RAW file is present in a Workplace.

## Immediate next action

1. Finish PR #7 scope only.
2. Get PR #7 CI/native validation green.
3. Merge PR #7 to `main`.
4. Retire `feature/workplaces-foundation` after merge.
5. Create `feature/workplaces-import-ux` from updated `main`.
6. Implement Queue 1 before Queue 2.

## Handoff maintenance rule

At the end of every merged PR:

1. Update `docs/PROJECT_HANDOFF.md` current state.
2. Mark the completed queue item with merge PR/commit information.
3. Move exactly one next queue item to **Current**.
4. Update supporting specs only when their technical/design decisions change.
5. Keep unrelated project plans out of this repository handoff.
