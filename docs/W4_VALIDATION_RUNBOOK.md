# W4 Desktop Validation Runbook

This runbook is the execution companion to `docs/W4_DESKTOP_VALIDATION.md`.

The checklist defines the acceptance gates. This runbook standardizes how evidence is collected so a physical W4 validation session can be reproduced and reviewed later.

## 1. Start from the commit to validate

Use a clean working tree on the exact commit intended for validation.

```bash
git status --short
git rev-parse HEAD
```

Do not mix local feature changes into the physical validation result.

## 2. Record preflight evidence

```bash
make w4-validation-preflight
```

This writes a timestamped evidence directory under:

```text
build/w4-validation/<timestamp>/
```

The environment report records:

- Git commit and branch;
- dirty working-tree state;
- OS/version;
- Flutter/Dart/Rust/Cargo versions;
- detected Flutter devices;
- disk/mount usage snapshot.

Set another evidence root when needed:

```bash
W4_EVIDENCE_DIR=/path/to/evidence make w4-validation-preflight
```

Do not commit generated evidence directories by default. Copy selected logs/screenshots into a durable review location only when a validation result needs to be retained.

## 3. Run the focused automated baseline

Before manipulating removable storage, run:

```bash
make w4-validation-automated
```

The focused baseline runs:

```text
flutter analyze --fatal-infos
asset_browser_controller_test.dart
import_controller_test.dart
asset_thumbnail_cache_test.dart
catalog_profile_test.dart
cargo check
cargo test
```

A physical PASS should not be recorded against a commit whose focused automated baseline fails.

## 4. Prepare physical data

Prepare separate source sets where practical:

```text
linked-source/
  at least 20 raster/RAW files on removable storage

managed-source/
  multiple files large enough to exercise mid-import disconnect

large-catalog/
  representative real assets for D7
```

For D7, the automated profile fixture already covers 5,000 catalog records structurally. Physical interaction should use at least 1,000 real assets when storage/time permits; record the actual number if lower.

## 5. Execute D1-D8 in order

Use `docs/W4_DESKTOP_VALIDATION.md` as the source of truth.

Recommended order:

```text
D1 linked disconnect/reconnect
D2 missing managed destination before import
D3 managed destination disappears during import
D4 replacement managed destination
D5 restart recovery of interrupted import
D6 thumbnail cache recovery / RAW boundary
D7 representative large catalog
D8 catalog-only removal safety
```

The order intentionally performs destructive/disruptive storage operations before the final catalog-only removal regression.

## 6. Evidence standard per gate

For each D1-D8 gate, retain enough evidence to answer:

```text
Commit tested:
Gate:
Status: PASS | FAIL | DEFERRED
Observed behavior:
Expected behavior:
Screenshot/log path:
Unexpected side effects:
```

For disconnect/reconnect gates, record the actual volume path before and after mounting. For managed-copy gates, verify both catalog state and filesystem state; UI-only observation is insufficient.

For D3 specifically, verify that the stale managed root was not recreated on the internal filesystem after the external volume disappeared.

For D5, verify catalog counts before and after Retry so duplicate prevention is demonstrated rather than inferred.

For D6 corruption recovery, alter only the generated cache entry, never the source original.

For D8, verify physical files with Finder/Explorer or shell after catalog removal.

## 7. Large-catalog observations

For D7, record at least:

```text
catalog asset count
source media type mix
initial process memory if available
peak/final process memory if available
availability-scan observation
thumbnail-population observation
Grid scroll observation
Filmstrip interaction observation
sort-change observation
crash/hang: yes/no
```

Do not invent fixed millisecond thresholds from CI profile tests; physical validation is primarily looking for lockups, runaway resource pressure, stale state and data-integrity failures.

## 8. Finalize the checklist

Update `docs/W4_DESKTOP_VALIDATION.md` only with evidence actually observed on the tested commit.

Allowed final results remain:

- `PASS`
- `PASS WITH DEFERRED GATES`
- `FAIL`
- `NOT VALIDATED`

A CI-green commit with no removable-volume session remains `NOT VALIDATED`.

## 9. W4 completion decision

W4 can be marked complete when:

1. W4 code/review/CI is green;
2. D1-D8 are PASS, or an explicitly accepted deferral is documented;
3. no gate reveals a data-integrity issue requiring a code fix;
4. `PROJECT_HANDOFF.md` and `CODE_WALKTHROUGH.md` are updated with the final physical result.

If a physical gate fails, create/fix the failure on a dedicated branch, rerun automated validation, then repeat the affected physical gate on the new commit. Do not carry a PASS from an older commit across a behavior-changing fix.
