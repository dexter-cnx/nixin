# M2 — Authoritative Workplace/catalog read adapter

## Goal

Expose the current authoritative Workplace/catalog read model to production frontends without giving GPUI storage or mutation ownership.

Canonical read path:

```text
GPUI presentation
  -> dextryx_frontend_api::CatalogReadApplication
  -> dextryx_core::CatalogReadRepository
  -> authoritative durable-source adapter
```

## First slice implemented

- split `CatalogReadRepository` from mutation-capable `CatalogRepository`;
- make `CatalogRepository` extend the read contract rather than mixing reads and writes in one trait;
- add `CatalogReadApplication<R>` to the frontend-neutral API;
- retain stable `WorkplaceDto`, `AssetSummaryDto`, linked/managed semantics, missing state, import sequence, and `AssetQuery` filtering;
- add a contract test proving the read application can query Workplaces/assets using only the read boundary.

This is intentionally a type-system boundary first. Production GPUI must not be wired to the synthetic repository as persistence authority.

## Durable-source adapter rule

Flutter/Hive remains the current durable persistence authority until the storage migration milestone. M2 must therefore bridge reads from that authority without:

- opening Hive directly from GPUI;
- defining a second durable catalog database;
- duplicating mutation/import persistence semantics;
- letting read code mutate active Workplace, relink assets, or remove catalog records.

Any interchange representation used while Hive remains authoritative must be treated as a transient read projection, not a second persistence authority. The durable adapter must map existing Workplace/asset identities and linked/managed paths exactly.

## Next slice

1. define the authoritative read-source projection contract around the existing Flutter repository model;
2. implement the current durable-source adapter behind `CatalogReadRepository`;
3. wire production GPUI startup/refresh to `CatalogReadApplication`;
4. expose real Workplace list + active Workplace + filtered asset reads;
5. add parity fixtures against the existing Flutter repository serialization;
6. keep every mutation path deferred to M4.

## Acceptance gates

- protected shared crates remain free of GPUI/Flutter/Dart/FFI dependencies;
- production GPUI performs no direct Hive access;
- read-only consumers cannot acquire catalog mutation methods through the M2 service;
- stable asset/workplace identity is preserved;
- linked/managed effective-path semantics remain unchanged;
- no second durable persistence authority exists;
- shared Rust tests, Clippy, formatting, production GPUI build, and existing Flutter validation remain green.
