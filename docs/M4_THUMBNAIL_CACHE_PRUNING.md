# M4 — GPUI Thumbnail Disk Cache Pruning

## Scope

This slice closes the filesystem-pressure limitation explicitly deferred from M3.

The GPUI thumbnail cache remains disposable derived data. It is not catalog authority and is never used as a durable source of truth.

## Bounds

The production macOS GPUI cache now enforces:

- maximum 2,048 regular thumbnail PNG entries;
- maximum 512 MiB of regular thumbnail PNG data;
- `.partial` generation files are excluded from normal cache accounting;
- oldest regular cache entries are removed first until both limits are satisfied.

Maintenance runs once on the first `ThumbnailWorkingSet::sync` in a process and again after successful new thumbnail generation.

## Version cleanup

Cache filenames contain two hashes:

```text
<stable-asset-id-hash>-<source-version-hash>.png
```

The source-version hash includes the effective source path plus available file size and modification time. After a new thumbnail is committed successfully, older versions carrying the same stable asset prefix are removed.

This keeps source invalidation semantics while preventing old size/mtime-keyed versions for one asset from accumulating indefinitely.

## Guardrails

- no original image is modified;
- no RAW demosaic work is introduced;
- GPUI still decodes only pixel-bounded generated thumbnails;
- cache maintenance failures are soft failures and do not make the catalog unavailable;
- cache pruning does not mutate Workplaces, assets, imports, or authoritative persistence.

## Tests

The Rust unit tests cover:

- bounded in-memory working set;
- RAW/missing fallback behavior;
- stable cache path identity;
- distinct stable asset identity even when effective source paths match;
- stale-version deletion for the same asset;
- entry/byte pruning while preserving `.partial` files.
