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
- native raster file selection for JPEG/PNG/TIFF/WebP;
- GPUI image rendering from a local filesystem path;
- Fit, 1:1 and incremental zoom controls;
- a bottom Filmstrip placeholder;
- a Develop inspector placeholder;
- a direct Rust-to-Rust linkage check against the existing `raw-engine` crate.

It does **not** replace Flutter, change Workplaces persistence, implement the production Import flow, change RAW behavior, or change PixelCraft processing ownership.

## Why this is worth testing

The current application already has a standalone Rust image engine. A GPUI desktop shell can consume that crate directly instead of crossing Dart FFI for every engine interaction. This potentially simplifies image-buffer ownership, background processing, cancellation, cache coordination and future GPU resource ownership.

The experiment also maps naturally to the existing Dextryx desktop structure:

```text
GPUI application
├── Workplace/catalog navigation
├── Image viewport
├── Filmstrip
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

For S1, click `Open Image` and select a JPEG, PNG, TIFF or WebP image. The toolbar provides `Fit`, `1:1`, zoom out and zoom in controls.

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

### S1 — Real image viewport — IN PROGRESS

Implemented in the spike branch:

- native file picker for one raster image;
- local JPEG/PNG/TIFF/WebP dimension probe;
- local image path rendered through GPUI's `img(...)` element;
- Fit mode using `ObjectFit::Contain`;
- 1:1 mode;
- bounded incremental zoom from 10% to 800%.

Still required before S1 is PASS:

- physical macOS validation of image open/render;
- pointer/trackpad pan while zoomed;
- resize behavior validation with a real image;
- direct rendering of an image buffer produced by `raw-engine`, rather than relying only on GPUI's path-based raster decoder;
- confirm the intended BGRA/RGBA ownership/conversion contract and count avoidable copies.

GPUI's current `img()` path-based image element is useful for the first raster validation. Upstream GPUI also supports `ImageSource::Image`, `ImageSource::Render` and `ImageSource::Custom`; these are the candidates for the raw-engine buffer experiment. GPUI internally paints decoded image data as render-image data, and current upstream source uses BGRA-oriented image data on this path. Do not assume a zero-copy engine-to-GPU contract until it is measured.

### S2 — Filmstrip

- load at least 5,000 catalog-like asset records;
- virtualize Filmstrip rendering;
- selection remains responsive while scrolling;
- thumbnail work remains asynchronous and bounded.

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

The repository's `raw-engine` is already an `rlib` in addition to `cdylib` and `staticlib`, so a Rust desktop binary can link it as a normal Rust dependency. The spike calls `raw_engine::check_engine()` directly and that direct linkage has now been observed successfully on the user's physical macOS machine.

S0 is therefore complete. S1 is the current gate.
