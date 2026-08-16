# Dextryx Images — Project Handoff

> Canonical status and execution queue for this repository. This file decides what gets worked on next and in what order.

## Current repository state

- Product name: **Dextryx Images**
- Compact app label: **Dxtr Imgs**
- Canonical application/bundle ID: `com.cnxdev.dextryx.images`
- Repository remains `dexter-cnx/nixin`
- Existing studio workspace milestone UI-01 through UI-15 is complete and retained as historical/compatibility capability.
- Current active implementation branch: `feature/workplaces-foundation`
- Current open PR: **PR #7 — Workplace Core + product identity**
- Canonical product direction: **image management / catalog / Workplaces**.
- PixelCraft / Dextryx Pixels is the dedicated **photo-editing / image-processing** product.
- Future integration may invoke PixelCraft as an external editor from Nixin.

## Canonical product boundary — Nixin vs PixelCraft

This section overrides any earlier roadmap wording that blurred the responsibilities of the two products.

### Nixin / Dextryx Images

**Primary role: image manager / catalog / Workplaces product.**

Nixin owns:

```text
Workplaces
asset catalog identity
import / folder discovery
linked vs managed source storage
asset organization
thumbnail/preview browsing
grid / filmstrip selection
missing / relink workflows
catalog metadata
large-library UX
future ratings / flags / keywords / search when explicitly scheduled
external-edit orchestration
```

### PixelCraft / Dextryx Pixels

**Primary role: photo editor + image-processing product.**

PixelCraft owns:

```text
edit session UX
Rust authoritative recipes/history/checkpoints
image-processing semantics
adjustments / masks / transforms
GPU preview
Film / Creative processing
render / export
editor recovery / session continuity
```

### Future external-edit direction

Expected long-term relationship:

```text
Nixin / Dextryx Images
  owns asset + Workplace/catalog identity
  ↓ external edit request
PixelCraft / Dextryx Pixels
  owns edit session + processing + render/export
  ↓ edited result / recipe reference / return contract
Nixin resumes asset management
```

Guardrails:

1. Nixin must not become authoritative for PixelCraft edit recipes or committed pixel semantics.
2. PixelCraft must not become authoritative for Nixin Workplaces/library organization.
3. Do not create two competing authoritative catalogs.
4. The external-edit protocol is future work and must be explicitly designed/versioned before implementation.
5. Existing Nixin Develop/Rust behavior may remain for compatibility and current workflows, but new heavy image-processing roadmap work must not be pulled forward by default.
6. Do not copy PixelCraft editor roadmap items into Nixin unless explicitly approved for Nixin.

## Canonical document map

| Document | Role |
|---|---|
| `docs/PROJECT_HANDOFF.md` | Canonical current status and execution order |
| `docs/WORKPLACES_HANDOFF.md` | Detailed Workplaces/catalog/import specification |
| `docs/DEXTRYX_IDENTITY.md` | Canonical product naming and identifier rules |
| `docs/DEXTRYX_IMAGES_HANDOFF.md` | Identity migration record/checklist |
| `docs/STUDIO_WORKSPACE_HANDOFF.md` | Historical/completed studio/editor milestone; not the forward product roadmap |
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
Future external-editor contract with PixelCraft
```

The normal image-management path should stay short:

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
Browse / organize / select
  ↓
Edit when needed
    ├── current embedded Develop compatibility path
    └── future: Open/Edit in PixelCraft
```

The goal is **not** to make Nixin duplicate PixelCraft's processing roadmap.

## Existing Develop capability — corrected status

Nixin already contains real Rust/FFI editing behavior from the completed Studio milestone. Keep it working while Workplaces evolves, but treat it as an existing compatibility capability rather than the primary future product direction.

Allowed maintenance:

- regressions and stability fixes;
- ensuring imported assets can still open in the existing Develop surface;
- preserving current mask/LUT/export behavior;
- lightweight integration changes required by Workplaces.

Not a default forward roadmap:

```text
new advanced adjustment families
new masking engines
GPU processing architecture expansion
real RAW demosaic/debayer pipeline
new film-processing platform
large processing-engine redesign
```

If those capabilities become strategically necessary, first decide whether they belong in PixelCraft and/or the future external-edit contract.

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
- establish the Nixin ↔ PixelCraft product boundary

Explicitly excluded:

- W2 import implementation
- Workplace grid/browser beyond W1 needs
- unrelated package/plugin work
- new image-processing behavior
- PixelCraft external-edit protocol implementation

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
double-click      open selected asset in current Develop path
future            Open/Edit in PixelCraft when external-edit contract exists
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

### Queue 5 — Future external-editor integration

Only after Workplaces/catalog flows are stable and only with an explicit cross-product design.

Design before implementation:

```text
launch/deep-link/IPC mechanism
asset/source handoff contract
security/path-access model
edit session identity
recipe/result return contract
version negotiation
cancel/failure behavior
who owns exported derivatives
how Nixin refreshes metadata/thumbnail after return
```

PixelCraft remains the editing/processing authority; Nixin remains the management/catalog authority.

## Immediate next action

1. Finish PR #7 scope only.
2. Get PR #7 CI/native validation green.
3. Merge PR #7 to `main`.
4. Retire `feature/workplaces-foundation` after merge.
5. Create `feature/workplaces-import-ux` from updated `main`.
6. Implement Queue 1 before Queue 2.
7. Do not start new processing-engine work merely because the embedded Develop surface exists.

## Handoff maintenance rule

At the end of every merged PR:

1. Update `docs/PROJECT_HANDOFF.md` current state.
2. Mark the completed queue item with merge PR/commit information.
3. Move exactly one next queue item to **Current**.
4. Update supporting specs only when their technical/design decisions change.
5. Keep unrelated project plans out of this repository handoff.
6. Re-check the Nixin ↔ PixelCraft ownership boundary before adding any catalog or processing milestone.