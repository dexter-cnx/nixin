# Dextryx Images CI Architecture

This document defines the repository CI contract for `dexter-cnx/nixin`.

## Goals

CI is split into three layers:

1. **Fast CI** catches cheap failures before expensive runners start.
2. **Affected CI** runs only the heavy jobs implied by the change domains.
3. **Full validation** runs the complete cross-platform quality bar for merge candidates.

Application/runtime behavior is outside the scope of this CI architecture.

## Local workflow

Before pushing, run:

```bash
make preflight
```

`make preflight` resolves Flutter dependencies and runs repository shell syntax checks, changed-file Dart formatting, Flutter analysis, fast Flutter tests, changed-file Rust formatting, Clippy and `cargo check`.

Useful narrower commands:

```text
make format-check
make analyze
make test-fast
make rust-format-check
make rust-clippy
make rust-check
make ci-fast
```

`make validate` remains the broader local Flutter + Rust validation command.

### Existing formatting/lint baseline

At the time this CI architecture was introduced, `main` already contained Dart/Rust source that was not fully formatter-clean and the handwritten Rust FFI boundary also contained existing `dead_code` and `clippy::not_unsafe_ptr_arg_deref` findings. Reformatting or changing those FFI functions would be unrelated product/native work, so this CI PR does not rewrite them.

The regression policy is therefore:

- Dart formatting is enforced on changed Dart files.
- Rust formatting is enforced on changed Rust source files.
- Clippy remains strict with `-D warnings`, but explicitly allows only the two documented legacy classes: `dead_code` and `clippy::not_unsafe_ptr_arg_deref`.
- all other Clippy warnings remain fatal.

The two Clippy allowances are a named baseline exception, not permission to broaden lint suppression. Removing them should be done in a focused Rust/FFI cleanup once the corresponding ABI/runtime implications are intentionally addressed.

## Fast CI

`.github/workflows/ci.yml` runs for PRs to `main`, pushes to `main`, and merge-queue `merge_group` checks. Feature-branch pushes are intentionally not a second CI trigger, avoiding duplicate push + pull-request runs.

The dependency graph for a normal PR begins:

```text
Detect changes
    |
    v
 Fast CI
    |
    +---------------- affected heavy jobs ----------------+
```

Fast CI always validates repository shell/YAML syntax. Flutter setup/checks run only when Flutter, FFI, import/filesystem or CI paths are affected. Rust setup/checks run only when Rust, FFI, export-engine or CI paths are affected.

On `merge_group`, Fast CI deliberately runs the shared Flutter/Rust/FFI preflight regardless of the affected-domain result so the stable `PR CI required` check is reported for the merge-group SHA. The affected heavy jobs are skipped on `merge_group`; the separate Full validation workflow owns the complete platform matrix there, avoiding duplicated expensive runners.

This guarantees new Dart/Rust formatting, lint and compile failures are detected before platform runners are allowed to start.

## Central change detection

`tool/ci-detect-changes.sh` is the only change-domain classifier used by PR CI. It exposes outputs from the `Detect changes` job rather than duplicating path expressions in every job.

Domains:

- `docs`: README/docs/Markdown changes.
- `flutter`: `lib/**`, `test/**`, `integration_test/**`, Flutter manifests/config/assets.
- `rust`: `rust/**` and Cargo manifests/lockfiles.
- `ffi`: Dart/Rust FFI API, bridge/loader/bindings paths.
- `platform`: platform-specific Android/iOS/macOS/Windows/Linux paths.
- `import-filesystem`: Workplaces/import/file-picker/storage/catalog/filesystem paths.
- `export-engine`: engine/export/LUT/mask/DevelopSettings/native processing paths.
- `ci`: workflows, Makefile/project build configuration and CI/helper shell scripts.

A CI-domain change intentionally enables broad affected validation because CI code can change which gates execute.

## Affected CI behavior

### Docs-only

Runs change detection, repository syntax sanity and the always-present required aggregate check. It skips unrelated Flutter/Rust/platform build matrices.

### Flutter-only UI/state

Runs Flutter format/analyze/fast tests, then the full standard Flutter test suite. It does not regenerate or rebuild native/FFI/platform artifacts unless engine/FFI/import-sensitive paths are also touched.

### Rust-only

Runs Rust format/Clippy/check before `cargo test`. Native/platform builds run because the shipped native artifact changed. Pure Flutter-only heavy suites are skipped unless the bridge/import domain is also affected.

### FFI

Runs both Flutter and Rust fast checks, FFI smoke validation, full Flutter/Rust tests and all configured platform builds.

The repository currently uses a handwritten Dart/Rust C-ABI boundary rather than generated `flutter_rust_bridge` bindings, so there is no FRB regeneration job to run. If generated bindings are introduced, they belong to this domain and must gain a deterministic generated-code-current check.

### Platform-specific

A platform-only path activates Fast CI plus that platform build. Shared Rust/FFI/engine/import changes broaden platform coverage automatically.

### Import/filesystem

Runs Flutter tests plus the configured platform build coverage because file picker, Workplaces persistence, managed/linked storage and entitlement-sensitive behavior are cross-platform contracts.

### Export/native engine

Runs Rust tests, FFI-sensitive validation when bridge paths are touched, and configured platform native/build checks.

## Required PR check

`PR CI required` always runs with `if: always()` and accepts only successful affected jobs or intentionally skipped unaffected jobs. This is the stable branch-protection check for normal PR feedback.

Whole-workflow `paths:` filtering is intentionally not used, avoiding required-check states that never report because a workflow was skipped.

The same workflow listens for `merge_group` so the repository remains compatible with GitHub Merge Queue if it becomes available in the future.

## Full validation

`.github/workflows/full-validation.yml` is deliberately separate from change-aware PR feedback CI. It runs on:

- normal pull requests targeting `main`,
- GitHub merge queue (`merge_group: checks_requested`) for future compatibility, and
- explicit `workflow_dispatch` for manual full validation.

For pull requests, draft PRs defer the expensive full matrix. `Merge gate` reports successfully for a draft, and marking the PR ready for review triggers a fresh full-validation run. Subsequent commits to the same PR cancel obsolete full-validation runs so old candidate matrices do not keep consuming runners.

Full validation does not use change filtering. Its `Merge gate` requires all of the following to succeed for the current merge candidate:

- full preflight: repository syntax, candidate-delta Dart/Rust formatting, Flutter analyze, strict baseline-aware Clippy, Rust compile check and FFI smoke;
- all standard Flutter tests;
- all Rust tests + release native build;
- Android native + release APK build;
- iOS native + release no-codesign build;
- macOS native + release app build;
- Windows Rust + Flutter release build;
- Linux Rust + Flutter release build.

This preserves the final cross-platform quality bar. Normal PR feedback remains change-aware in `ci.yml`, while a ready-for-review PR must also pass the full matrix before merge.

## Branch-protection requirement

The repository is currently owned by a personal GitHub account, so GitHub Merge Queue is not available in its current repository configuration. Protected `main` therefore uses normal pull-request validation and should require both stable aggregate checks:

```text
CI / PR CI required
Full validation / Merge gate
```

`Require branches to be up to date before merging` should be enabled so the required checks are evaluated against a PR that includes the latest `main` before it can merge.

Both workflows retain `merge_group` support so the repository can move to merge-queue validation later without redesigning the CI topology if repository ownership/plan changes make Merge Queue available.

## Caching and concurrency

- Flutter uses `subosito/flutter-action` caching.
- Rust uses `Swatinem/rust-cache` keyed from the Rust workspace/manifests/toolchain inputs.
- identical format/lint checks are kept on Ubuntu rather than repeated per OS.
- PR CI uses `cancel-in-progress: true` scoped by PR/ref, so superseded commits stop consuming runners.
- PR-triggered Full validation is scoped by PR number and cancels obsolete candidate runs when a new commit arrives.
- merge-group/manual Full validation remains scoped by candidate SHA and is not cancelled by unrelated runs.

## Examples

```text
Formatting-only Dart fix
  Detect -> Fast CI -> Flutter full tests -> PR CI required
  Ready PR -> Full validation matrix -> Merge gate

Docs-only fix
  Detect -> Fast CI(repository syntax only) -> PR CI required
  Ready PR -> Full validation matrix -> Merge gate

Flutter-only change
  Detect -> Fast CI(Flutter) -> Flutter full tests -> PR CI required
  Ready PR -> Full validation matrix -> Merge gate

Rust-only change
  Detect -> Fast CI(Rust) -> Rust tests + configured platform builds -> PR CI required
  Ready PR -> Full validation matrix -> Merge gate

FFI change
  Detect -> Fast CI(Flutter+Rust+FFI) -> Flutter/Rust tests + all platform builds -> PR CI required
  Ready PR -> Full validation matrix -> Merge gate

iOS-only change
  Detect -> Fast CI(repository syntax) -> iOS build -> PR CI required
  Ready PR -> Full validation matrix -> Merge gate

CI/workflow change
  Detect -> Fast CI(Flutter+Rust) -> broad affected validation -> PR CI required
  Ready PR -> Full validation matrix -> Merge gate

Future merge-queue candidate
  CI: Detect -> Fast CI -> affected heavy jobs skipped -> PR CI required
  Full validation: Full preflight -> all Flutter/Rust/platform jobs -> Merge gate
```

## Merge guarantee

Normal change-aware PR CI optimizes feedback. A ready-for-review PR cannot merge until both required aggregate checks pass. With `Require branches to be up to date before merging` enabled, the current fallback for this personal-account repository validates the latest PR candidate through `Full validation / Merge gate` before merge. If Merge Queue becomes available later, the existing `merge_group` triggers can be used as the stronger final-candidate mechanism without changing the full-validation matrix.
