# M1 — Production GPUI Shell

Status: COMPLETE
Branch: `feature/m1-gpui-production-shell`
PR: #22

## Goal

Establish the first production GPUI application shell for Dextryx Images without promoting experiment-only business logic into the frontend.

M1 owns presentation, window lifecycle, workspace navigation, command dispatch, frontend-local state, and file-selection orchestration only. Catalog persistence, import mutation, storage, thumbnail/cache, metadata, and image-processing semantics remain behind frontend-neutral Rust boundaries.

## Production structure

```text
apps/desktop-gpui/
  Cargo.toml
  src/
    app_state.rs       plain Rust command/navigation + import-selection state
    file_dialog.rs     production rfd adapter implementing FileDialogPort
    main.rs            GPUI window + presentation binding
```

The experiment remains under `experiments/gpui-desktop` as validation evidence. Production code does not depend on the experiment crate or its compatibility facade.

## Command/state rule

`DesktopAppState` and `AppCommand` contain no GPUI types. Catalog navigation uses `dextryx_frontend_api::AssetQuery`, so the production frontend speaks the stable application vocabulary from the first slice.

Current shell commands:

- Library workspace
- Develop workspace shell
- All photos
- Missing
- Recent imports
- Import selection

The Import button routes through a production `FileDialogPort` adapter. Selected paths are held only as frontend-local application input; M1 deliberately does not duplicate shared import semantics or create a second persistence authority. Authoritative import mutation/persistence remains a later M4 concern.

## File-dialog path

```text
GPUI click
  -> DesktopAppState::begin_import
  -> FileDialogPort
  -> RfdFileDialogAdapter
  -> selected paths as application-ready input
```

This path is mockable in unit tests and contains no direct GPUI-to-Hive coupling.

## Validation

`.github/workflows/gpui-production.yml` provides a macOS-first production shell gate:

- `cargo fmt -- --check`
- `cargo test`
- `cargo clippy --all-targets -- -D warnings`
- `cargo build`

Repository-wide changed-file formatting also covers `apps/desktop-gpui/**/*.rs`, and `make format` formats the production manifest.

Final M1 head validation (`cae235416ba0a160b0e8220847dd96b7cd20b4ca`):

- `CI #440` — success
- `GPUI Production Shell #14` — success
- `Full validation #55` — success
- production shell unit tests — 4/4 passed
- Rust 1.98 Clippy with `-D warnings` — passed

## Acceptance gate

- [x] Production GPUI crate is separate from the spike.
- [x] Plain-Rust desktop command/navigation state contains no GPUI types.
- [x] Catalog command vocabulary reuses the stable frontend API.
- [x] GPUI window renders the initial Library/Develop shell.
- [x] Production app is covered by local formatting and changed-file CI formatting.
- [x] Production GPUI macOS CI passes.
- [x] Import selection is wired through neutral `FileDialogPort` without GPUI-owned import semantics or persistence.
- [x] Production code does not require the transitional spike file-dialog compatibility facade.
- [x] Cancelled import selection clears stale frontend-local selection state.
- [x] No second durable catalog/import format is introduced.

## Next milestone

M2 introduces a **read-only authoritative Workplace/catalog adapter** behind the frontend/application API.

M2 must not make GPUI a persistence authority. It should establish a neutral read path that can expose authoritative Workplace/catalog data to the production shell while preserving stable asset identity and current durable semantics.
