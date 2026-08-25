# M4 Durable Catalog Authority Cutover Contract

Status: pre-cutover contract. No disk-backed Rust catalog authority is authorized by this document alone.

## Current authority

Flutter/KeyValueStore/Hive remains the single durable catalog authority. GPUI and Rust projection readers are consumers only. `CandidateCatalogStore` is an in-memory qualification adapter and must not be used as production persistence.

## Required guarantees before cutover

A production Rust persistence adapter is not eligible to become authoritative until all of these are proven:

1. **Atomic commit** — a catalog mutation is visible as either the complete old state or complete new state, never a torn intermediate state.
2. **Crash recovery** — process or machine failure during persistence cannot leave the catalog unreadable or silently lose committed state.
3. **Durable flush** — success is not reported before the persistence layer has reached the durability level promised by the adapter.
4. **Single writer enforcement** — Flutter/Hive and Rust must never both accept authoritative writes for the same catalog generation.
5. **Rollback support** — the old authority remains recoverable until the new authority has passed post-cutover verification.
6. **Snapshot round-trip verification** — the candidate can ingest the authoritative snapshot and reproduce all Workplace/asset identities and storage semantics without loss.
7. **Mutation parity verification** — active Workplace, relink and remove-from-catalog behavior matches the shared frontend-neutral contract.

The executable counterpart is `DurableAuthorityCapabilities` plus `is_cutover_ready()` in `dextryx-storage`. A missing requirement blocks cutover.

## Cutover procedure

### Phase A — prepare while Flutter/Hive is authoritative

- stop adding new persistence semantics that exist only in Flutter/Hive;
- export a complete authoritative typed projection;
- validate `validate_catalog_projection` before migration starts;
- preserve a rollback copy/generation identifier for the existing authority;
- instantiate the candidate store from the validated projection;
- verify shared parity fixture and full production-like snapshot round-trip;
- run mutation parity tests without enabling production writes.

### Phase B — maintenance boundary

Cutover must occur at an explicit write boundary. Do not switch authority while either frontend can continue writing.

1. Enter a short catalog-maintenance state that blocks new catalog mutations.
2. Flush the current Flutter/Hive authority.
3. Export and validate the final snapshot.
4. Persist that snapshot through the candidate durable adapter.
5. Re-open the candidate and independently snapshot it back through `CatalogSnapshotRepository`.
6. Compare identities and catalog semantics against the final source snapshot.
7. Only after verification succeeds, change the authority marker/configuration to Rust.
8. Keep the previous durable source intact for rollback until the acceptance window closes.

No GPUI mutation command may be enabled before step 7 completes successfully.

### Phase C — post-cutover verification

Immediately after switching authority:

- read Workplaces and assets through the same frontend-neutral read API used by GPUI;
- verify active Workplace;
- verify linked vs managed effective paths;
- verify missing-state flags;
- exercise one reversible test mutation or a dedicated migration canary record;
- restart the app/process and verify the committed state survives;
- verify only the Rust authority accepts writes.

If any verification fails, disable Rust writes and restore the previous authority before allowing more catalog mutations.

## Rollback rules

Rollback must not merge two diverged authorities. If Rust has accepted user mutations after cutover, rollback requires either:

- replaying an authoritative mutation journal into the old store; or
- restoring the pre-cutover source and explicitly discarding post-cutover mutations with user-visible recovery handling.

Therefore a real production adapter should provide a monotonic catalog generation/revision and a mutation journal or equivalent transactional recovery mechanism before broad rollout.

## Production adapter requirements

A real disk-backed adapter should live below the frontend/application layer, preferably in `dextryx-storage`, and explicitly implement:

- `CatalogReadRepository`
- `CatalogSnapshotRepository`
- `AuthoritativeCatalogPersistence`

It must not depend on GPUI, Flutter, Dart or FFI crates. Projection/cache adapters must never gain write authority through blanket trait implementations.

## Deferred implementation choices

This contract deliberately does not yet choose SQLite, Dxtr_Box or another engine. The storage engine decision is separate from the authority/migration semantics. Any engine must satisfy the same cutover gate.

## Exit criteria for the next slice

The next disk-backed-adapter slice may begin only after its design can demonstrate how it will satisfy every `CutoverRequirement`, including crash-injection tests and restart durability tests. Until then, Flutter/Hive remains the sole durable authority.
