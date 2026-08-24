# M1 — Production GPUI Shell

Status: IN PROGRESS
Branch: `feature/m1-gpui-production-shell`

## Goal

Establish the first production GPUI application shell for Dextryx Images without promoting experiment-only business logic into the frontend.

M1 owns presentation, window lifecycle, workspace navigation, command dispatch, and frontend-local state only. Catalog, import, storage, thumbnail/cache, metadata, and image-processing semantics remain behind frontend-neutral Rust boundaries.

## Initial production structure

```text
apps/desktop-gpui/
  Cargo.toml
  src/
    app_state.rs   plain Rust command/navigation state
    main.rs        GPUI window + presentation binding
```

The experiment remains under `experiments/gpui-desktop` as validation evidence. Production code must not depend on the experiment crate.

## Command/state rule

`DesktopAppState` and `AppCommand` contain no GPUI types. Catalog navigation uses `dextryx_frontend_api::AssetQuery`, so the production frontend speaks the stable application vocabulary from the first slice.

Current shell commands:

- Library workspace
- Develop workspace shell
- All photos
- Missing
- Recent imports
- Import command placeholder routed toward the application boundary

The Import button deliberately does not duplicate import semantics in GPUI. Wiring it to `FileDialogPort` + shared import/application services is the next M1 slice.

## Validation

`.github/workflows/gpui-production.yml` provides a macOS-first production shell gate:

- `cargo fmt -- --check`
- `cargo test`
- `cargo clippy --all-targets -- -D warnings`
- `cargo build`

Repository-wide changed-file formatting also covers `apps/desktop-gpui/**/*.rs`, and `make format` formats the production manifest.

## Acceptance gate

- [x] Production GPUI crate is separate from the spike.
- [x] Plain-Rust desktop command/navigation state contains no GPUI types.
- [x] Catalog command vocabulary reuses the stable frontend API.
- [x] GPUI window renders the initial Library/Develop shell.
- [x] Production app is covered by local formatting and changed-file CI formatting.
- [ ] Production GPUI macOS CI passes.
- [ ] Import command is wired through neutral dialog/application ports without GPUI-owned import logic.
- [ ] Transitional spike file-dialog compatibility facade is no longer required by production code.

## Next slice

Wire `Import` through a production frontend adapter:

```text
GPUI click
  -> frontend-local command handler
  -> FileDialogPort adapter
  -> frontend/application API
  -> shared Import execution contract
```

No direct GPUI-to-Hive path and no second durable catalog/import format are allowed.
