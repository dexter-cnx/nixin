# M4 Unix Snapshot Replacement Qualification

This slice introduces a dedicated snapshot replacement primitive for the Rust disk-backed catalog candidate.

## Qualified behavior

On Unix targets, including macOS, `replace_snapshot(temp, destination)` delegates directly to `rename(temp, destination)` and does not pre-delete the destination. Qualification tests cover:

- replacing an existing destination with a prepared snapshot;
- consuming the temporary file on success;
- preserving the existing destination when replacement fails before rename.

This removes the explicit remove-then-rename destination-missing window from the replacement primitive itself.

## Windows guardrail

Windows replacement semantics are not yet qualified. The Windows implementation returns `Unsupported` instead of silently falling back to destination deletion followed by rename.

## Capability status

This slice alone does **not** change `DurableAuthorityCapabilities`. In particular, the following remain unproven:

- parent-directory durability after replacement;
- crash recovery across filesystem and power-loss boundaries;
- single-writer enforcement;
- rollback/recovery generation semantics;
- Windows replacement behavior.

The disk-backed candidate remains non-authoritative and Flutter/KeyValueStore/Hive remains the sole production durable writer.

## Next

Wire `replace_snapshot` into `DiskCandidateCatalogStore`, remove the old `AfterDestinationRemoved` checkpoint, and rerun the existing deterministic fault matrix. Only after that integration proves that every injected failure reopens either the old complete snapshot or the new complete snapshot should the atomic-commit capability be reconsidered for the qualified platform set.
