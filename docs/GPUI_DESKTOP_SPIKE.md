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

### S2 — Filmstrip / catalog scale — FINAL VALIDATION

Already physically validated:

- 5,000 synthetic catalog-like asset records;
- large-catalog virtualization concept;
- rapid scrolling and selection responsiveness on physical macOS.

Current implementation now also contains:

- true horizontal Filmstrip visible-range virtualization;
- three-item overscan on each side;
- only visible/overscan Filmstrip elements are constructed;
- GPUI background-executor thumbnail work;
- maximum 4 thumbnail jobs in flight;
- queued off-screen work is replaced by the latest visible range before it starts;
- completed thumbnails are bounded by a 128-entry cache.

Still required before S2 is marked PASS:

- compile/run the latest horizontal Filmstrip + async-thumbnail implementation on physical macOS;
- confirm thumbnails progressively appear;
- confirm Filmstrip scroll remains responsive while thumbnail jobs run;
- confirm selection remains immediate while jobs run;
- confirm displayed in-flight count never exceeds 4;
- confirm queue does not grow continuously during fast scrolling.

### S3 — Workplace/catalog boundary — STATE SHELL IN PROGRESS

The first S3 layer is now implemented without moving persistence ownership:

```text
CatalogView
├── AllPhotos
├── Missing
└── RecentImports
```

Current synthetic behavior:

- `All photos` exposes all 5,000 stable assets;
- `Missing` exposes every 17th asset as a deterministic missing subset;
- `Recent imports` exposes the latest 500 assets;
- changing Catalog view resets Filmstrip position and selects the first asset in that view;
- the underlying `asset_ix` remains stable across filters;
- Filmstrip virtualization and thumbnail caching operate on stable asset identity rather than view position.

This state shell is deliberately separate from persistence. The next S3 step is to define a catalog/workplace repository boundary and adapt production Workplaces data through it without teaching GPUI about Hive or moving storage semantics into UI code.

S3 acceptance still requires preserving production semantics for:

- stable asset identity;
- linked vs managed storage;
- missing/relink behavior;
- catalog-only removal;
- recent-import membership;
- Workplace selection.

### S4 — Desktop compatibility

- validate macOS packaging and filesystem dialogs;
- compile/smoke Linux;
- compile and launch on Windows before treating Windows as supported.

### S5 — Decision

Choose one of:

1. stop the experiment and keep Flutter desktop;
2. use GPUI only for a specialized desktop viewport/shell;
3. incrementally migrate desktop UI to GPUI while retaining Flutter for mobile;
4. migrate the desktop application fully to Rust/GPUI.

## Guardrails

- No Big Bang rewrite.
- Do not port Workplaces persistence before S1/S2 prove a material benefit.
- Do not duplicate PixelCraft image-processing ownership.
- Do not resume real RAW demosaic/debayer work as part of this experiment.
- Keep the Flutter production path buildable throughout the experiment.
- Treat GPUI API churn as a real maintenance cost in the final decision.
- Keep catalog filtering/state independent from persistence implementation details.

## Current evidence

The repository's `raw-engine` is already an `rlib` in addition to `cdylib` and `staticlib`, so a Rust desktop binary can link it as a normal Rust dependency. S0 and S1 are complete on physical macOS. The earlier S2 large-catalog virtualization/selection proof is also physically validated. The latest horizontal Filmstrip/background-thumbnail implementation is awaiting physical validation, while S3 now has a live catalog-state shell ready for repository-boundary work.
