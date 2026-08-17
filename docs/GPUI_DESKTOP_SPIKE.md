# Dextryx Images — GPUI Desktop Spike

This experiment evaluates GPUI as a possible future desktop UI shell for Dextryx Images without changing the production Flutter application.

## Scope

Branch: `agent/gpui-desktop-spike`

Experiment path:

```text
experiments/gpui-desktop/
```

Spike 0 intentionally contains only:

- a desktop application/window shell;
- Workplace/navigation panel placeholders;
- a central image viewport placeholder;
- a bottom Filmstrip placeholder;
- a Develop inspector placeholder;
- a direct Rust-to-Rust linkage check against the existing `raw-engine` crate.

It does **not** replace Flutter, change Workplaces persistence, implement Import, decode images, alter RAW behavior, or change PixelCraft processing ownership.

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

The spike is macOS-first. Linux is useful for compile/smoke validation. Windows should be treated as an explicit compatibility gate rather than assumed production-ready.

## Run

From the repository root:

```bash
cd experiments/gpui-desktop
cargo run
```

Expected first result: a dark Dextryx desktop shell with Workplace, viewport, Filmstrip and Develop regions. The top bar reports whether the existing `raw-engine` crate linked successfully.

## Validation gates

Do not consider a GPUI migration until all of these are demonstrated.

### S0 — Build / launch

- macOS debug build succeeds;
- application launches and resizes correctly;
- existing `raw-engine` links directly;
- no change is required to the Flutter production build.

### S1 — Real image viewport

- open one raster image;
- render it in the GPUI viewport;
- resize, fit, 1:1, zoom and pan remain responsive;
- define image-buffer ownership with no avoidable copies across an FFI boundary.

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

The repository's `raw-engine` is already an `rlib` in addition to `cdylib` and `staticlib`, so a Rust desktop binary can link it as a normal Rust dependency. The first spike calls `raw_engine::check_engine()` directly to prove that intended dependency direction at source level.

The source has been scaffolded in GitHub, but it has **not yet been physically compiled or launched on the user's macOS/Windows machines**. A real-device build remains the next evidence gate.
