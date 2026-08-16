# Dextryx Images — Identity Handoff

> Status: FINAL naming decision. Apply this identity while continuing the current Workplaces implementation. Do not rename the GitHub repository.

## Final product identity

- Master brand: **Dextryx**
- Product name: **Dextryx Images**
- Compact app label: **Dxtr Imgs**
- Canonical application/bundle ID: `com.cnxdev.dextryx.images`
- Repository: `dexter-cnx/nixin` (unchanged)
- Dart/internal package names: unchanged for now

## Usage rules

Use **Dextryx Images** for full product-facing contexts:

- application/window title
- About screen
- installer/store metadata
- documentation and product copy
- future product-family references

Use **Dxtr Imgs** only for compact launcher/application labels where shorter text is useful.

Do not shorten the master product identity to `DXTR` alone. `Dxtr Imgs` is a compact label, not the canonical brand name.

## Identifier migration

All shipping platform identifiers should converge on:

```text
com.cnxdev.dextryx.images
```

Test targets should use:

```text
com.cnxdev.dextryx.images.RunnerTests
```

The identifier configuration must remain variable-driven through `project.mk` / `tool/configure-identifiers.sh`; do not reintroduce hard-coded setup-only identifier scripts.

## Scope guardrails

This identity change must not trigger unrelated refactors.

- keep repo name `nixin`
- keep current Dart package/import names
- do not rename Rust crates/FFI symbols solely for branding
- do not change RAW/image-processing behavior
- do not interrupt Workplaces W1 architecture

## Fast implementation order

1. Update canonical identity metadata and handoff.
2. Update Flutter product title to `Dextryx Images`.
3. Update launcher/application label to `Dxtr Imgs`.
4. Migrate Android namespace/application ID and `MainActivity` package.
5. Apply `com.cnxdev.dextryx.images` to iOS/macOS/test targets through the canonical identifier configuration.
6. Align Linux/Windows product metadata.
7. Run analyze/tests and native identity checks before merge.

## Acceptance criteria

- UI/full title presents `Dextryx Images`.
- compact native app label presents `Dxtr Imgs` where applicable.
- all shipping IDs resolve to `com.cnxdev.dextryx.images`.
- test bundle suffix remains `.RunnerTests`.
- repository remains `dexter-cnx/nixin`.
- existing Workplaces and image-processing tests do not regress.
