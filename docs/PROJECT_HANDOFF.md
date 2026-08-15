# Dextryx Images — Project Handoff

> Canonical status and execution queue for the repository. Detailed design/specification documents remain authoritative for their own scope, but this file decides what gets worked on next and in what order.

## Current repository state

- Product name: **Dextryx Images**
- Compact app label: **Dxtr Imgs**
- Canonical application/bundle ID: `com.cnxdev.dextryx.images`
- Repository remains `dexter-cnx/nixin`
- Existing studio workspace milestone UI-01 through UI-15 is complete.
- Current active implementation branch: `feature/workplaces-foundation`
- Current open PR: **PR #7 — Workplace Core + product identity**
- Real RAW development / demosaic / debayer remains deferred.
- New image-processing features must not be allowed to derail Workplaces/catalog UX work.

## Canonical document map

Use this file first when resuming work.

| Document | Role |
|---|---|
| `docs/PROJECT_HANDOFF.md` | Canonical current status and execution order |
| `docs/WORKPLACES_HANDOFF.md` | Detailed Workplaces/catalog/import specification |
| `docs/DXTR_SEGMENT_HANDOFF.md` | Detailed reusable segmentation package / MobileSAM ONNX specification |
| `docs/DEXTRYX_IDENTITY.md` | Canonical product naming and identifier rules |
| `docs/DEXTRYX_IMAGES_HANDOFF.md` | Historical identity migration checklist; not a separate work queue |
| `docs/STUDIO_WORKSPACE_HANDOFF.md` | Historical/completed studio workspace milestone |
| `docs/CODE_WALKTHROUGH.md` | Code orientation/reference |

Do not create an additional handoff that competes with `PROJECT_HANDOFF.md`. New plans should either update this execution queue or live as a detailed supporting specification referenced from here.

## Product priority

The immediate product problem is no longer the studio shell. It is that the catalog/import experience still feels like a test application.

The priority order is therefore:

```text
Workplace core
    ↓
Modern import UX
    ↓
Workplace browser / filmstrip integration
    ↓
Desktop catalog hardening
    ↓
Reusable local AI segmentation foundation
    ↓
Advanced Develop / real RAW pipeline
```

The user should be able to reach the normal photo-management path with minimal decision overhead:

```text
Launch
  ↓
My workplace
  ↓
Import
  ↓
Select photos/folder
  ↓
Review only when useful
  ↓
Assets appear in Workplace
  ↓
Select / double-click
  ↓
Develop
```

## PR policy from this point forward

Keep one implementation purpose per PR. Documentation for future phases may be present in the repository, but future implementation must not be mixed into the current PR.

### PR #7 — finish and merge first

Branch: `feature/workplaces-foundation`

Purpose:

- W1 Workplace Core
- final Dextryx Images identity migration already performed on the branch
- canonical handoff consolidation

Allowed in PR #7:

- Workplace / AssetRecord domain and persistence foundation
- `My workplace` initialization
- create / switch / rename / delete Workplace behavior
- current Workplace persistence
- user-facing Library → Workplaces rename
- product identity / bundle-ID changes already part of this branch
- documentation consolidation

Do not add to PR #7:

- W2 import implementation
- Workplace grid/browser implementation beyond what W1 requires
- MobileSAM/ONNX implementation
- real RAW development
- new image-processing behavior

Merge gate:

```text
flutter analyze
flutter test
cargo check / existing Rust validation
native identity validation where applicable
```

After PR #7 is green, merge it before starting the next implementation PR.

## Execution queue

### Queue 1 — UX-01 / W2A: Import Simplification

Create a fresh branch from updated `main` after PR #7 merges.

Recommended branch:

```text
feature/workplaces-import-ux
```

Goal: remove the current test-app feeling from the primary asset-entry flow.

Implement:

- primary action is simply **Import**
- clicking Import opens multi-select image/file picker directly
- folder import moves to secondary action/menu
- desktop copy/reference choice is not presented as three peer actions
- storage behavior becomes an import option and remembers the previous/default choice
- modern empty Workplace state
- drag/drop affordance on desktop
- no success modal after normal import completion
- unobtrusive progress/status presentation

Primary UX rule:

> Ask the user what they want to import, not how the internal import implementation should work.

Acceptance:

- adding common photos is one obvious primary action
- no three-choice dialog before normal photo selection
- secondary import modes remain discoverable
- existing W1 persistence remains intact
- no new image processing

### Queue 2 — W2B: Import Pipeline + Review

Recommended branch after Queue 1 merges:

```text
feature/workplaces-import-pipeline
```

Implement the durable import system from `WORKPLACES_HANDOFF.md`:

- multi-file import
- folder import
- recursive discovery
- supported-format filtering
- ImportBatch
- async progress and cancellation
- duplicate detection
- linked/add mode
- desktop managed/copy mode
- managed destination preference
- safe partial-failure semantics
- optional compact Import Review when useful

UX requirement:

- Import Review is not a mandatory multi-page wizard.
- Keep the normal path short.
- Storage options use progressive disclosure.

Acceptance:

- 100+ supported mixed assets can be imported without freezing the UI
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

Desktop interaction target:

```text
single click      select
Ctrl/Cmd click    multi-select where supported
Shift click       range selection where supported
double-click      open selected asset in Develop
Space             preview / loupe-style view when implemented
```

Filmstrip should primarily belong to the Develop/selected-asset workflow rather than consuming permanent vertical space in an empty catalog screen.

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
- hover/focus/selection transitions
- restrained motion and progress feedback

Guardrail:

Catalog removal and physical deletion must remain distinct actions.

### Queue 5 — DXTR Segment P1-P3: reusable MobileSAM ONNX foundation

Start only after the core Workplaces browsing/import path is stable. This track remains independent from RAW development.

Recommended branch:

```text
feature/dxtr-segment-foundation
```

Target package:

```text
packages/dxtr_segment
```

Public package concept is model-agnostic segmentation. MobileSAM ONNX is the first backend, not the long-term API identity.

First bounded delivery:

- Rust/native ONNX Runtime lifecycle
- MobileSAM encoder + decoder reference pipeline
- preprocessing / coordinate transforms / postprocessing
- Flutter plugin API
- `PreparedImage` / image-embedding lifecycle
- point prompt segmentation
- standalone package example independent of Dextryx Images UI
- CPU FP32 reference/golden validation

Do not start with:

- quantization
- automatic everything segmentation
- generative fill
- object removal
- SAM2 video segmentation
- cloud inference

Critical architecture rule:

```text
image
  ↓
encoder (expensive, once per image/revision)
  ↓
PreparedImage / embedding cache
  ↓
point/box/refinement prompts
  ↓
decoder (interactive)
  ↓
mask
```

See `docs/DXTR_SEGMENT_HANDOFF.md` for detailed architecture and P1-P7 roadmap.

### Queue 6 — DXTR Segment P4-P7 + Nixin mask integration

Only after the standalone package foundation is proven.

Implement incrementally:

- positive/negative prompt refinement
- box prompt
- previous-mask refinement
- embedding cache hardening
- cancellation/latest-request-wins
- memory lifecycle
- XNNPACK/CoreML/NNAPI benchmarks
- Nixin/Dextryx adapter
- editable Mask UI integration

Nixin owns mask UX and persistence. `dxtr_segment` owns inference.

### Queue 7 — Advanced Develop / real RAW pipeline

Still deferred until the catalog workflow and segmentation foundation are stable enough to justify returning to image-processing architecture.

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

Current action is **not** to open another implementation PR.

Do this in order:

1. Finish PR #7 scope only.
2. Get PR #7 CI/native validation green.
3. Merge PR #7 to `main`.
4. Delete or retire `feature/workplaces-foundation` after merge.
5. Create `feature/workplaces-import-ux` from the updated `main`.
6. Implement Queue 1 before Queue 2.

## Handoff maintenance rule

At the end of every merged PR:

1. Update `docs/PROJECT_HANDOFF.md` current state.
2. Mark the completed queue item with merge PR/commit information.
3. Move exactly one next queue item to **Current**.
4. Update the detailed supporting spec only when its technical/design decisions changed.
5. Do not create a new top-level handoff file for routine continuation.

This keeps one status source, detailed specs reusable, and PR scope bounded.