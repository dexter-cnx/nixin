# M4 Persistence Fault Injection

This work qualifies the Rust disk-backed catalog candidate against deterministic filesystem interruption points. It does not change the current durable authority: Flutter/KeyValueStore/Hive remains the sole production writer.

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

`PersistenceFaultInjector` can return the typed `CatalogMutationError::Persistence` at any checkpoint. `NoPersistenceFaults` is the normal no-op implementation.

`DiskCandidateCatalogStore::apply_candidate_mutation_with_faults` now wires those checkpoints into the real candidate snapshot path. The injected path deliberately does not perform synthetic cleanup after the injected checkpoint; this models abrupt interruption closely enough for the qualification tests to reopen the destination and observe what a later process would see.

## Qualification evidence

The reopen-after-failure tests now document the current replacement behavior precisely:

- faults from `BeforeTempCreate` through `BeforeDestinationReplace` leave the old destination snapshot readable and complete;
- a fault at `AfterDestinationRemoved` leaves no destination snapshot to reopen, proving a real recovery gap in the current remove-then-rename strategy;
- a fault at `AfterDestinationRename` leaves the new destination snapshot readable and complete, while the current in-memory store has not yet published the mutation;
- injected persistence failures remain typed as `DiskCandidateError::Persistence` and never masquerade as repository/domain lookup failures;
- normal no-fault mutation behavior still persists and reopens successfully.

The `AfterDestinationRemoved` result is intentionally negative evidence. It is the reason the candidate must not claim atomic commit or crash recovery yet.

## Capability status

The disk candidate continues to report these durability capabilities as false:

- `atomic_commit`
- `crash_recovery`
- `durable_flush`
- `single_writer_enforced`
- `rollback_supported`

Snapshot round-trip and mutation parity remain qualified, but those are insufficient for durable-authority cutover.

## Next qualification slice

Replace the remove-then-rename sequence with a platform-qualified replacement strategy that never creates a destination-missing window, then rerun the same fault matrix. The next slice must demonstrate that every pre-publication interruption reopens the old complete snapshot and every post-publication interruption reopens the new complete snapshot. Parent-directory durability, single-writer ownership, and rollback/recovery generations remain separate gates after that.
