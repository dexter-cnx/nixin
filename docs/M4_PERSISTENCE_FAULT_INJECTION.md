# M4 Persistence Fault Injection

This slice introduces deterministic persistence checkpoints for qualifying the Rust disk-backed catalog candidate. It does not change the current durable authority: Flutter/KeyValueStore/Hive remains the sole production writer.

## Fault points

`dextryx-storage::PersistenceFaultPoint` defines explicit checkpoints around the snapshot write lifecycle:

1. `BeforeTempCreate`
2. `AfterTempCreate`
3. `AfterSnapshotWrite`
4. `BeforeFileSync`
5. `AfterFileSync`
6. `BeforeDestinationReplace`
7. `AfterDestinationRemoved`
8. `AfterDestinationRename`

`PersistenceFaultInjector` can return the typed `CatalogMutationError::Persistence` at any checkpoint. `NoPersistenceFaults` is the production-safe no-op implementation.

## Why this is a separate contract

Failure injection must be deterministic before filesystem behavior is used as cutover evidence. The checkpoints are deliberately named around observable persistence phases instead of implementation-specific test flags. This lets qualification tests prove what remains readable after each failed phase without coupling the frontend or core domain model to a concrete filesystem implementation.

## What this slice proves

- persistence failures have deterministic, typed injection seams;
- the no-op injector permits every checkpoint;
- an injected checkpoint can fail exactly once and then allow retry;
- the contract remains in `dextryx-storage`, below frontend/application code.

## What this slice does not prove

It does not yet prove atomic replacement, crash recovery, parent-directory durability, single-writer locking, or rollback. Those `DurableAuthorityCapabilities` remain false.

## Next qualification slice

Wire these checkpoints into `DiskCandidateCatalogStore` snapshot persistence, then run fault-injection tests that reopen the store after every injected failure. Before destination replacement, reopen must expose the old complete snapshot. Around replacement, the tests must document and then eliminate any state in which neither the old nor the new complete snapshot is available. Only after the replacement and recovery strategy satisfies that invariant should `atomic_commit`, `crash_recovery`, or `durable_flush` be reconsidered.
