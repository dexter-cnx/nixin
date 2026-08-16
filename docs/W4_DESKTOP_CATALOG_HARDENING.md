# W4 Desktop Catalog Hardening

This document describes the implementation and acceptance boundary for W4 in Dextryx Images.

## Scope

W4 hardens the Workplaces/catalog layer for real desktop filesystem behavior. It does not expand RAW development, image-processing semantics, or PixelCraft processing ownership.

W4 is split into:

```text
W4-A  missing detection, relink, disconnected-volume behavior, catalog-only removal
W4-B1 managed destination/copy recovery and import-batch recovery
W4-B2 thumbnail/cache hardening and representative large-catalog profiling
```

## W4-A — merged in PR #12

PR #12 established:

- asynchronous file availability scanning outside Grid/Filmstrip tiles;
- persisted `missing` state;
- disconnected-volume catalog behavior;
- Locate Missing File / Locate Missing Folder;
- managed-copy filename-aware folder relink;
- ambiguous filename safety;
- scan-vs-remove/relink race protection;
- catalog-only removal with no physical original deletion.

Merge commit:

```text
f5fb16bdf84f61d92fe93dc7f03c35777227df3b
```

## W4-B1 — managed/import recovery

Current branch:

```text
feature/w4b-managed-import-recovery
```

### Managed destination recovery

A remembered managed root must be validated before use.

Policy:

```text
remembered root exists
  -> use it

remembered root missing/unmounted
  -> do not create that path automatically
  -> request a replacement destination
  -> replacement must already exist
  -> persist replacement only after validation
```

The non-recreation rule is important for removable/external storage: recreating a missing mount path can silently redirect managed originals to the wrong local filesystem.

### Managed copy commit protocol

Managed copies use a small commit protocol:

```text
source file
  -> select collision-free final path
  -> copy to <final>.partial
  -> rename partial to final
  -> persist AssetRecord
```

Invariants:

- never overwrite an existing destination file;
- asset IDs are checked for catalog collision before use;
- copy failure removes `.partial` output;
- cancellation after copy but before catalog commit removes the uncommitted copy;
- catalog persistence failure removes the newly copied managed original;
- source originals are never deleted or moved.

This keeps filesystem state and catalog state aligned as closely as possible without introducing a database/filesystem transaction manager.

### ImportBatch recovery metadata

New batches persist:

```text
storageMode
sourcePaths
failedPaths
```

The `running` ImportBatch is saved before per-file processing starts. This makes an interrupted batch discoverable after a process/app failure and retains enough source-path context to retry.

Backward compatibility:

```text
legacy storageMode missing -> linked
legacy sourcePaths missing  -> []
legacy failedPaths missing  -> []
```

Older persisted Hive maps therefore remain readable.

### Retry semantics

`retryBatch(batchId)` follows these rules:

- retry only when the current batch has failed paths or was left `running`;
- original Workplace must be active;
- completed/failed partial batch retries `failedPaths` only;
- interrupted `running` batch retries all saved `sourcePaths`;
- original batch `storageMode` overrides the current UI storage option;
- retry creates a new import attempt/batch;
- existing source-path duplicate detection prevents already-successful assets from being duplicated;
- newly imported recovery result can flow through the existing browser/Develop post-import synchronization.

### UI recovery

Studio import controls expose:

- explicit failed-import status;
- **Retry failed import** in the panel when the current batch is recoverable;
- the same retry action from the import options menu.

## W4-B1 regression coverage

Automated tests cover:

- normal managed-copy import;
- stale remembered managed root is not recreated;
- validated replacement destination is remembered;
- destination collision does not overwrite an existing file;
- catalog-save failure cleans up the newly copied managed original;
- source original survives managed-copy failure;
- partial import records failed source paths;
- failed path can be retried without duplicating prior successes;
- retry is blocked from a different Workplace;
- recovery metadata and managed storage mode round-trip through `ImportBatch.toMap/fromMap`;
- legacy ImportBatch maps remain readable.

## W4-B1 acceptance gates

- disconnected remembered managed root cannot silently redirect copy output;
- managed destination collisions never overwrite existing files;
- no `.partial` file is left after a handled copy failure;
- failed catalog write does not leave a newly copied managed original orphaned;
- interrupted/partial batches retain enough source metadata for retry;
- retry preserves original Workplace and original storage mode semantics;
- retry cannot duplicate already-successful source paths;
- existing W4-A missing/relink/removal behavior remains intact;
- `flutter analyze` passes;
- `flutter test` passes;
- `cargo check` passes;
- `cargo test` passes.

## W4-B2 — remaining work

### Thumbnail/cache hardening

- generate/write browser thumbnail or preview cache without coupling Grid/Filmstrip to RAW processing internals;
- atomic/collision-safe cache writes;
- tolerate missing/corrupt cache files;
- invalidate stale cache records safely;
- bound memory and filesystem pressure;
- avoid full-source decode work on the UI-critical browser path where possible.

### Large-catalog profiling

Use representative catalog sizes rather than only small unit fixtures. Measure at minimum:

- Workplace load latency;
- availability scan duration;
- Grid/Filmstrip scroll responsiveness;
- memory growth;
- persistence write amplification;
- thumbnail/cache pressure;
- folder-relink indexing cost.

### Manual desktop gates

At minimum verify on desktop:

- managed root on external storage, disconnect/reconnect;
- stale saved managed root chooses replacement correctly;
- failed/partial import recovery after restarting the app;
- large catalog remains usable while availability/cache work occurs.

W4 is not complete until W4-B2 is implemented or explicitly moved to a later documented milestone.

## Guardrails

- Dextryx Images remains catalog authority;
- PixelCraft / Dextryx Pixels remains processing authority;
- no RAW demosaic/debayer work in W4;
- no implicit physical deletion;
- no silent recreation of a missing managed mount/root;
- no overwrite-based managed copy collision policy;
- no broad state-management rewrite solely for this milestone;
- no per-tile synchronous filesystem probing.
