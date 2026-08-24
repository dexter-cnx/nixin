# M2 — Authoritative Workplace/catalog read adapter

## Goal

Expose the current authoritative Workplace/catalog read model to production frontends without giving GPUI storage or mutation ownership.

Canonical read path:

```text
GPUI presentation
  -> dextryx_frontend_api::CatalogReadApplication
  -> dextryx_core::CatalogReadRepository
  -> ProjectionCatalogReadAdapter
  -> projection supplied by the current durable-source boundary
```

## Implemented slices

- split `CatalogReadRepository` from mutation-capable `CatalogRepository`;
- make `CatalogRepository` extend the read contract rather than mixing reads and writes in one trait;
- add `CatalogReadApplication<R>` to the frontend-neutral API;
- add `AuthoritativeCatalogProjection` as a typed in-memory hand-off model;
- add read-only `ProjectionCatalogReadAdapter` implementing `CatalogReadRepository`;
- support projection replacement for explicit refresh without adding persistence semantics;
- retain stable `WorkplaceDto`, `AssetSummaryDto`, linked/managed semantics, missing state, import sequence, and `AssetQuery` filtering;
- add contract tests for read-only queries, identity preservation, and managed effective-path behavior.

`AuthoritativeCatalogProjection` is deliberately **not** a storage/file format. Production GPUI must not persist it or promote the synthetic repository as persistence authority.

## Durable-source adapter rule

Flutter/Hive remains the current durable persistence authority until the storage migration milestone. M2 must therefore bridge reads from that authority without:

- opening Hive directly from GPUI;
- defining a second durable catalog database;
- duplicating mutation/import persistence semantics;
- letting read code mutate active Workplace, relink assets, or remove catalog records.

The existing Flutter domain serialization is the mapping reference:

- Workplace identity: `Workplace.id`;
- Workplace display name: `Workplace.name`;
- active Workplace: `currentWorkplaceId` from the existing settings repository;
- Asset identity: `AssetRecord.id`;
- Workplace ownership: `AssetRecord.workplaceId`;
- source path: `AssetRecord.sourcePath`;
- managed path: `AssetRecord.managedPath`;
- storage mode: `AssetRecord.storageMode` (`linked` / `managed`);
- missing state: `AssetRecord.missing`;
- effective path semantics: managed path when present, otherwise source path.

Any interchange mechanism used while Hive remains authoritative is a transient read projection only. It must never become a second source of truth.

## Next slice

1. implement the current durable-source projection provider from existing Flutter repositories;
2. refresh the projection atomically when authoritative Workplace/catalog state changes;
3. provide the projection to the production GPUI read boundary without exposing Hive to GPUI;
4. wire production GPUI startup/refresh to `CatalogReadApplication`;
5. expose real Workplace list + active Workplace + filtered asset reads;
6. add parity fixtures against the existing Flutter repository serialization;
7. keep every mutation path deferred to M4.

## Acceptance gates

- protected shared crates remain free of GPUI/Flutter/Dart/FFI dependencies;
- production GPUI performs no direct Hive access;
- read-only consumers cannot acquire catalog mutation methods through the M2 service;
- stable asset/workplace identity is preserved;
- linked/managed effective-path semantics remain unchanged;
- no second durable persistence authority exists;
- shared Rust tests, Clippy, formatting, production GPUI build, and existing Flutter validation remain green.
