# Dextryx Images — GPUI Desktop Spike

This experiment evaluates GPUI as a possible future desktop UI shell for Dextryx Images without changing the production Flutter application.

## Scope

Branch: `agent/gpui-desktop-spike`

Experiment path:

```text
experiments/gpui-desktop/
```

The spike currently contains:

- a desktop application/window shell;
- Workplace/navigation panel placeholders;
- a central image viewport;
- native image/RAW-preview file selection;
- direct Rust-to-Rust linkage against the existing `raw-engine` crate;
- a safe native Rust `raw-engine` preview/develop entry point returning owned RGBA pixels;
- direct raw-engine RGBA -> GPUI `RenderImage` rendering without C FFI, temporary image files, or PNG/JPEG re-encoding;
- Fit, 1:1 and incremental zoom controls;
- mouse drag pan;
- trackpad/two-finger scroll pan;
- pinch zoom and Cmd/Ctrl-scroll zoom;
- a 5,000-asset horizontal Filmstrip stress harness;
- visible-range + overscan virtualization;
- bounded background thumbnail generation with max 4 in-flight jobs;
- a 128-entry thumbnail cache;
- live Catalog state for All photos / Missing / Recent imports;
- stable synthetic asset identity across Catalog filters;
- a framework-neutral Rust `CatalogRepository` boundary and contract tests;
- production-like linked/managed, effective-path, relink, catalog-removal and Workplace-selection semantics in the S3 test adapter;
- a Develop inspector placeholder.

It does **not** replace Flutter, move production Workplaces persistence, implement the production Import flow, add real RAW demosaic/debayer behavior, or change PixelCraft processing ownership.

## Why this is worth testing

The current application already has a standalone Rust image engine. A GPUI desktop shell can consume that crate directly instead of crossing Dart FFI for every engine interaction. This potentially simplifies image-buffer ownership, background processing, cancellation, cache coordination and future GPU resource ownership.

The experiment maps naturally to the existing Dextryx desktop structure:

```text
GPUI application
├── Workplace/catalog navigation
├── Image viewport
├── Filmstrip / catalog virtualization
├── Inspector / Develop controls
└── Commands / shortcuts
        │
        └── raw-engine (direct Rust dependency)
```

## Dependency policy

GPUI is pre-1.0 and upstream changes can break applications. The spike therefore pins `gpui` and `gpui_platform` to one Zed repository commit instead of following `main` implicitly.

Pinned Zed commit at spike creation:

```text
fd90c0af7f021d89e511dd9a5f92d4f04ec29314
```

`gpui_platform` enables the `font-kit` feature because physical macOS validation showed that the default spike built and painted layout surfaces but did not discover/render system fonts without it.

The spike is macOS-first. Linux is useful for compile/smoke validation. Windows should be treated as an explicit compatibility gate rather than assumed production-ready.

## Run

From the repository root:

```bash
cd experiments/gpui-desktop
cargo run
```

S3 repository-boundary contract validation:

```bash
cargo test --test catalog_boundary
```

## S1 interaction checks

- `Open Image` opens a raster or current RAW-preview format;
- `Fit` resets zoom and pan;
- `1:1` resets to 100%;
- `+` / `-` changes zoom;
- left or middle mouse drag pans;
- two-finger/trackpad scrolling pans;
- pinch zooms;
- Cmd/Ctrl + scroll zooms.

## S1 buffer ownership

The current direct path is:

```text
file path
  -> raw_engine::develop_preview(...)
  -> DevelopedImage { width, height, Vec<u8> RGBA }
  -> in-place RGBA/BGRA channel swizzle at GPUI boundary
  -> image::RgbaImage::from_raw(...)
  -> image::Frame
  -> gpui::RenderImage
  -> GPUI renderer / image atlas
```

The pinned GPUI renderer expects BGRA-oriented render-image bytes. The channel swizzle is performed in place at the UI boundary. No intermediate JPEG/PNG encoding or temporary file is introduced.

The existing C ABI remains intact for Flutter. The native Rust entry point is additive and is used only by the GPUI experiment at this stage.

## Validation gates

Do not consider a GPUI migration until all of these are demonstrated.

### S0 — Build / launch — PASS on physical macOS

Observed on the user's Mac:

- macOS debug build succeeds;
- Metal shader compilation succeeds after installing Xcode's Metal Toolchain component;
- application launches and paints the expected desktop shell;
- system text renders after enabling `gpui_platform/font-kit`;
- existing `raw-engine` links directly and the UI reports `raw-engine linked`;
- Flutter production code remains untouched by the experiment.

### S1 — Real image viewport — PASS on physical macOS

Implemented and physically validated on the user's Mac:

- native file picker for raster and current embedded-RAW-preview formats;
- image decode/develop through `raw-engine`, not GPUI's file-path decoder;
- owned engine RGBA buffer passed into GPUI `RenderImage` without an encoded-image round trip;
- correct visible image rendering through the direct buffer path;
- Fit / 1:1 / bounded zoom;
- left/middle mouse drag pan;
- trackpad/two-finger scroll pan;
- pinch and Cmd/Ctrl-scroll zoom;
- direct Rust-to-Rust engine integration remains functional while interacting with the viewport.

Do not claim engine-to-GPU zero-copy. The current improvement removes the Dart/C FFI boundary and avoids an encoded-image/file round trip, but GPUI still owns renderer/image-atlas upload behavior.

### S2 — Filmstrip / catalog scale — PASS on physical macOS

Physically validated on the user's Mac:

- 5,000 synthetic catalog-like asset records;
- true horizontal Filmstrip visible-range virtualization;
- three-item overscan on each side;
- only visible/overscan Filmstrip elements are constructed;
- GPUI background-executor thumbnail work;
- maximum 4 thumbnail jobs in flight;
- queued off-screen work is replaced by the latest visible range before it starts;
- completed thumbnails are bounded by a 128-entry cache;
- thumbnails progressively appear;
- Filmstrip scrolling remains responsive while thumbnail jobs run;
- selection remains responsive while jobs run;
- observed in-flight count stays within the configured bound;
- queue behavior remains bounded under fast scrolling.

S2 provides positive evidence that GPUI can support a catalog-heavy desktop Filmstrip workload without constructing the entire asset set in the live element tree.

### S3 — Workplace/catalog boundary — PASS on physical macOS

The S3 Catalog state shell is physically validated:

```text
CatalogView
├── AllPhotos
├── Missing
└── RecentImports
```

Validated UI behavior:

- `All photos` exposes all 5,000 stable assets;
- `Missing` exposes every 17th asset as a deterministic missing subset;
- `Recent imports` exposes the latest 500 assets;
- changing Catalog view resets Filmstrip position and selects the first asset in that view;
- the underlying synthetic asset identity remains stable across filters;
- Filmstrip virtualization and thumbnail caching operate on stable asset identity rather than view position;
- repeatedly switching Catalog views remains responsive on physical macOS.

The framework-neutral repository boundary in `experiments/gpui-desktop/src/catalog.rs` is also validated by:

```bash
cargo test --test catalog_boundary
```

The test command passes locally and `cargo run` continues to behave normally after the boundary was introduced.

Repository architecture:

```text
GPUI CatalogState / WorkplaceState
          ↓
framework-neutral CatalogRepository
          ↓
production adapter (decision deferred)
          ↓
authoritative catalog/storage implementation
```

The S3 contract models and tests:

- stable string asset identity independent from view position;
- `WorkplaceSummary` and active-Workplace selection;
- linked vs managed storage mode;
- `effective_path = managed_path ?? source_path`;
- relink preserving asset identity while updating the correct linked/managed path;
- missing state cleared by successful relink;
- recent-import membership/order;
- catalog-only removal with no physical-delete operation in the repository contract.

`SyntheticCatalogRepository` is only a test adapter. It is deliberately not a persistence proposal.

Production Flutter already has its own storage boundary from the merged storage-abstraction work:

```text
Flutter application/domain
        ↓
WorkplaceRepository / AssetRepository / ImportRepository
        ↓
repository adapters
        ↓
KeyValueStore / AppStorage
        ↓
current Hive backend
```

Therefore GPUI must **not** learn Hive APIs or duplicate persistence semantics.

## Architecture Review — COMPLETE

Full review:

```text
docs/GPUI_ARCHITECTURE_REVIEW.md
```

Decision:

**CONTINUE MIGRATION — incrementally, desktop-only, with S4 as the next hard gate.**

Architecture score: approximately **8.3/10 before S4**.

The decision is based on positive S0-S3 evidence for direct Rust engine integration, viewport interaction, 5,000-asset catalog virtualization, bounded asynchronous work, and a clean catalog-domain boundary.

This is **not** approval for a Big Bang rewrite, production persistence migration, Flutter desktop removal, or new RAW demosaic/debayer work.

### S4 — Desktop compatibility — NEXT

S4 is now authorized as the next spike gate only:

- validate macOS release packaging, app-bundle launch and filesystem dialogs;
- compile and launch the pinned GPUI spike on Windows;
- validate text, file dialog, direct raw-engine viewport and Filmstrip smoke on Windows;
- compile/smoke Linux and record required native dependencies;
- document the maintenance cost of moving the pinned GPUI revision forward.

Do not port additional production feature families merely to complete S4.

### S5 — Final migration decision

Only after S4 evidence.

## Guardrails

- No Big Bang rewrite.
- Do not port production Workplaces persistence before a separate storage architecture decision.
- Do not duplicate PixelCraft image-processing ownership.
- Do not resume real RAW demosaic/debayer work as part of this experiment.
- Keep the Flutter production path buildable throughout the experiment.
- Treat GPUI API churn as a real maintenance cost in the final decision.
- Keep catalog filtering/state independent from persistence implementation details.
- Keep the native catalog contract independent from GPUI and any concrete database.
- Do not add Hive knowledge to GPUI.
- S4 is compatibility/packaging evidence, not a feature-port milestone.

## Current evidence

```text
S0  PASS  native macOS build/launch/font/Rust linkage
S1  PASS  direct Rust image viewport + pan/zoom
S2  PASS  5,000-asset virtualized Filmstrip + bounded thumbnails
S3  PASS  Catalog state + framework-neutral repository contract

ARCHITECTURE REVIEW
     CONTINUE MIGRATION — incremental desktop-only

NEXT
S4   desktop compatibility / packaging / Windows-Linux gates
```
