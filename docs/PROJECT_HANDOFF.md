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
- **W4-B1 managed/import recovery: merged in PR #13**
- **W4-B2 thumbnail/cache + large-catalog hardening: merged in PR #14**
- W4-B2 merge commit on `main`: `f05a11590ad21320ebe02d2d7be55c990cea9fe0`
- Current focused engineering branch: `agent/full-validation-pr-trigger`
- Current engineering task: **CI feedback-time optimization with PR-based full validation; no runtime/product changes**
- W4 desktop physical validation remains a separate product-validation blocker.
- Detailed W4 guide: `docs/W4_DESKTOP_CATALOG_HARDENING.md`
- Desktop validation checklist: `docs/W4_DESKTOP_VALIDATION.md`
- CI architecture: `docs/CI_ARCHITECTURE.md`
- Real RAW demosaic/debayer and other new image-processing work remain deferred.

## Product responsibility

Dextryx Images owns Workplaces, catalog identity, import/storage organization, thumbnail/preview browsing, Grid/Filmstrip selection, missing/relink workflows, catalog metadata, large-library UX and future external-edit orchestration.

PixelCraft / Dextryx Pixels remains processing authority. Do not duplicate its processing roadmap here.

## Completed — W1 through W4-B2 code

W1 established Workplace/AssetRecord persistence and lifecycle.

W2 added live Workplace wiring plus multi-file/folder Import, linked/managed storage, ImportBatch persistence, duplicate prevention, progress and cancellation.

W3 added the persisted Workplace Grid, `AssetBrowserController`, one ordered asset list, one `selectedAssetId`, Grid ↔ Filmstrip synchronization, basic sorting and preview boundary.

W4-A added asynchronous missing-file detection, disconnected-volume behavior, single-file/folder relink, managed-copy filename relink correctness, availability-scan race protection and catalog-only removal.

W4-B1 added validated managed destinations, collision-safe/atomic managed copies, cleanup after copy/catalog failures, restart-safe ImportBatch restoration/retry, original-Workplace retry gating and preservation of user-selected storage preferences.

W4-B2 added catalog-level raster thumbnail caching and representative large-catalog profile gates:

- existing persisted `thumbnailPath` / `previewPath` take precedence;
- raster thumbnail generation is lazy and isolated from RAW processing ownership;
- RAW assets do not enter the raster source decoder path;
- raster decode/resize runs through `compute(...)`;
- distinct thumbnail generation is concurrency-bounded, while duplicate requests share one in-flight Future;
- generated cache keys include stable asset identity plus persisted version and current source file metadata (`mtime` + size), so externally changed/replaced sources invalidate stale cache entries;
- generated JPEG cache entries are decode-validated before reuse; corrupt entries are removed/regenerated;
- writes use `.partial` -> rename and cache maintenance is best-effort/non-fatal;
- pruning defaults to 2,048 files / 512 MiB;
- 5,000-asset fixtures cover Workplace load/sort and availability scans;
- availability concurrency is bounded at 32 and persistence write amplification is regression-tested.

## Current — CI feedback optimization

CI work is isolated from product/runtime behavior. The current personal-account-compatible architecture is:

```text
Detect changes
    -> Fast CI
        -> affected Flutter/Rust/platform jobs
            -> PR CI required

ready pull request targeting main
    -> Full validation preflight
        -> all Flutter/Rust/platform gates
            -> Merge gate
```

`tool/ci-detect-changes.sh` is the single change-domain classifier. PR CI uses job-level conditions rather than whole-workflow path filtering, so intentionally skipped heavy jobs do not leave the stable required aggregate check pending.

`Full validation` runs on non-draft pull requests targeting `main` and can also be run manually. Draft pull requests intentionally defer the expensive full matrix; marking a PR ready triggers validation. New commits cancel obsolete in-progress full-validation runs for the same PR.

Local developer pre-push command:

```text
make preflight
```

Full details and domain-to-job behavior are documented in `docs/CI_ARCHITECTURE.md`.

Important branch-protection follow-up: this repository is currently under a personal GitHub account, so Merge Queue is not available. Protected `main` should require `PR CI required` and `Merge gate`, and **Require branches to be up to date before merging** should be enabled. `Merge gate` must report on normal ready pull requests rather than depending on merge-group events. The connected GitHub App cannot inspect or modify `main` branch protection, so these repository settings must be verified separately by a repository administrator.

## W4 desktop physical validation

The remaining W4 blocker is real desktop evidence, not additional image-processing work.

`docs/W4_DESKTOP_VALIDATION.md` defines D1–D8 physical/manual gates for:

- linked external-volume disconnect/reconnect;
- managed destination missing before import;
- managed destination disappearing during import;
- replacement managed destination;
- restart recovery of persisted running/failed batches;
- thumbnail cache corruption/recovery and RAW boundary;
- representative large-catalog interaction;
- catalog-only removal safety.

Current validation status remains **NOT VALIDATED** until those gates are run on a real desktop filesystem.

### Validation tooling

`tool/w4-desktop-validation.sh` and Make targets provide reproducible evidence capture:

```text
make w4-validation-preflight
make w4-validation-automated
```

They record the current commit/branch, dirty-state, OS/toolchain/device information and disk state. The automated mode additionally runs Flutter analysis, focused W4 Workplaces tests, Rust check/test and writes logs beneath `build/w4-validation/<timestamp>/`.

The tooling does not mark D1–D8 PASS by itself; removable-volume/UI gates still require observed physical evidence.

## W4 guardrails

- catalog removal and physical deletion are separate operations;
- linked originals are never silently moved or deleted;
- missing/disconnected linked assets stay cataloged;
- a missing managed mount/root must not be silently recreated at the same path;
- managed copy must not overwrite an existing file;
- failed catalog writes must not leave newly copied managed originals orphaned;
- import retry must preserve catalog identity/duplicate safety and original storage semantics;
- thumbnail generation must not introduce RAW development/processing ownership into Workplaces;
- no synchronous source decode or filesystem existence probe inside Grid tile build;
- cache corruption/failure is recoverable and must not fail the catalog;
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

Recommended local gate before pushing:

```text
make preflight
```

Broader local gate:

```text
make validate
```

W4-B2 additionally includes `test/workplaces/catalog_profile_test.dart` and thumbnail-cache regression tests.

## Documentation map

```text
docs/PROJECT_HANDOFF.md                    canonical project status / execution queue
docs/CODE_WALKTHROUGH.md                   current code ownership and data flow
docs/CI_ARCHITECTURE.md                    fast/affected/full CI contract
docs/W4_DESKTOP_CATALOG_HARDENING.md       W4 implementation/recovery/acceptance guide
docs/W4_DESKTOP_VALIDATION.md              W4 physical desktop validation checklist
tool/ci-detect-changes.sh                   centralized CI change-domain classifier
tool/w4-desktop-validation.sh               environment/evidence + focused automated runner
```

## W4 completion boundary

Code/review/CI for W4-B2 are complete. W4 as a milestone is complete only after desktop/manual D1–D8 gates are recorded PASS, or a gate is explicitly approved/documented as deferred with rationale.

Do not claim physical external-volume gates passed without real desktop evidence.

## Future — PixelCraft external-editor integration

Only after catalog workflows stabilize. Dextryx Images remains catalog authority; PixelCraft remains processing authority. Future integration should exchange stable asset/edit references rather than duplicate processing internals.

## Immediate execution order

```text
DONE      W4-A  PR #12 missing/relink/catalog-removal hardening
DONE      W4-B1 PR #13 managed destination/copy + import-batch recovery
DONE      W4-B2 PR #14 thumbnail/cache + large-catalog profile gates
CURRENT   PR #17 PR-based full-validation / merge-gate alignment
PARALLEL  W4 physical D1-D8 desktop evidence remains outstanding
FUTURE    PixelCraft external-editor contract
```
