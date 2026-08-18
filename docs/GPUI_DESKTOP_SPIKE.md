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
- an S2 catalog-scale virtualization harness containing 5,000 synthetic asset records;
- selection state over the virtualized catalog rows;
- a Develop inspector placeholder.

It does **not** replace Flutter, change Workplaces persistence, implement the production Import flow, add real RAW demosaic/debayer behavior, or change PixelCraft processing ownership.

## Why this is worth testing

The current application already has a standalone Rust image engine. A GPUI desktop shell can consume that crate directly instead of crossing Dart FFI for every engine interaction. This potentially simplifies image-buffer ownership, background processing, cancellation, cache coordination and future GPU resource ownership.

The experiment also maps naturally to the existing Dextryx desktop structure:

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

For S1, click `Open Image` and select a JPEG/PNG/TIFF/WebP image or one of the existing RAW-preview formats. The toolbar provides `Fit`, `1:1`, zoom out and zoom in controls.

Interaction checks:

- `Fit` resets zoom and pan to fit the 720x480 validation viewport;
- `1:1` resets to 100% and centered pan;
- `+` / `-` changes zoom;
- left or middle mouse drag pans;
- two-finger/trackpad scrolling pans;
- pinch zooms;
- Cmd/Ctrl + scroll zooms.

For S2, use the bottom stress harness:

- it represents 5,000 catalog-like assets;
- records are grouped into 625 fixed-height virtual rows of eight assets each;
- GPUI `uniform_list` only builds the currently visible row range;
- rapidly scroll the harness and click assets while scrolling;
- the selected asset should update immediately without constructing all 5,000 thumbnail elements.

The row-based harness deliberately proves catalog-scale virtualization first. It is not yet the final horizontal Filmstrip implementation.

## S1 buffer ownership

The current direct path is:

```text
file path
  -> raw_engine::develop_preview(...)
  -> DevelopedImage { width, height, Vec<u8> RGBA }
  -> in-place RGBA/BGRA channel swizzle at GPUI boundary
  -> image::RgbaImage::from_raw(...)  // adopts Vec, no pixel-buffer clone
  -> image::Frame
  -> gpui::RenderImage
  -> GPUI renderer / image atlas
```

The pinned GPUI renderer expects BGRA-oriented render-image bytes. The channel swizzle is therefore performed in place at the UI boundary. No intermediate JPEG/PNG encoding or temporary file is introduced.

The existing C ABI remains intact for Flutter. The new native Rust entry point is additive and is used only by the GPUI experiment at this stage.

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

Follow-up soak/performance checks can still measure repeated image replacement, large-image memory behavior and resize ergonomics, but they are no longer blockers for the S1 architectural proof.

Do not claim engine-to-GPU zero-copy. The current improvement removes the Dart/C FFI boundary and avoids an encoded-image/file round trip, but GPUI still owns renderer/image-atlas upload behavior.

### S2 — Filmstrip / catalog scale — IN PROGRESS, virtualization validated on physical macOS

Implemented and physically validated so far:

- 5,000 synthetic catalog-like asset records;
- 625 fixed-height rows with eight assets per row;
- GPUI `uniform_list` virtualization, so only visible rows are built;
- clickable selection state over the virtualized records;
- rapid scrolling and selection work on the user's physical macOS machine without a blocking failure.

Still required before S2 is PASS:

- bounded asynchronous thumbnail generation/loading instead of `thumb pending` placeholders;
- verify thumbnail work does not block the UI thread;
- establish a bounded queue/cache policy and cancellation/drop behavior for off-screen work;
- implement and validate a true horizontal Filmstrip virtualization path rather than treating the row-based harness as the final UI.

The row-based harness is intentional: GPUI's current `uniform_list` is a vertical uniform-height virtual list. It is being used to prove large-catalog lazy rendering independently before we build a specialized horizontal Filmstrip element or adapter.

### S3 — Workplace/catalog boundary

- prove whether the existing Dart Workplace persistence should remain behind an adapter during migration or be ported to Rust;
- preserve stable asset identity and linked/managed storage semantics;
- preserve missing/relink/catalog-only removal behavior.

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

## Current evidence

The repository's `raw-engine` is already an `rlib` in addition to `cdylib` and `staticlib`, so a Rust desktop binary can link it as a normal Rust dependency. The spike calls `raw_engine::check_engine()` directly and that direct linkage has been observed successfully on the user's physical macOS machine.

S0 and S1 are complete on physical macOS. S2 catalog virtualization and selection are also physically validated; bounded async thumbnails and true horizontal Filmstrip virtualization remain before S2 can be closed.
