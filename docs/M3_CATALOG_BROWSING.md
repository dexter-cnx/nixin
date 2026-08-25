# M3 — GPUI Catalog Browsing Acceptance Evidence

## Status

M3 is implementation-complete after PR #25, PR #26, and PR #27.

Merged sequence:

- PR #25 — authoritative virtualized Filmstrip
- PR #26 — authoritative virtualized Grid + shared stable selection
- PR #27 — bounded production thumbnails and layout hardening

PR #27 squash-merged to `main` as `ada6a813e7fadb7c458db0f9984e38c00e4e4c86`.

## Production data path

```text
Flutter/Hive durable catalog authority
  -> disposable catalog projection
  -> dextryx-frontend-api CatalogReadApplication
  -> DesktopAppState authoritative DTOs
  -> virtualized GPUI Grid + Filmstrip
  -> bounded disposable thumbnail cache
```

No GPUI-to-Hive dependency and no second durable catalog authority were introduced.

## Stable selection

`DesktopAppState.selected_asset_id` is the single selection identity shared by Grid and Filmstrip.

Selection behavior:

- selection is stored by stable asset ID rather than view index;
- refresh/filter preserves selection when the asset remains present;
- deterministic fallback selects the first remaining asset when the selected asset disappears;
- Filmstrip selection recenters Grid when necessary;
- Grid selection updates the same state observed by Filmstrip.

## Grid virtualization

`apps/desktop-gpui/src/grid.rs` owns deterministic viewport math.

Current constants:

```text
columns        = 4
item width     = 184 px
item height    = 132 px
row gap        = 12 px
viewport       = 348 px
overscan rows  = 2
```

The Grid renders only the visible range plus overscan and keeps selection visible without materializing the full catalog.

Regression tests cover large-catalog bounded visible ranges and selection tracking.

## Filmstrip virtualization

The Filmstrip uses bounded horizontal viewport/overscan math from plain Rust `DesktopAppState` and renders only the current authoritative range.

Cards use authoritative asset identity, effective path, storage mode, and missing state. No synthetic catalog records are generated for GPUI.

## Production thumbnails

PR #27 addressed the critical requirement that GPUI must not decode full-resolution originals merely to draw small Grid/Filmstrip images.

Current policy:

- thumbnail working set is capped at 64 authoritative asset IDs;
- only selected/visible/overscan raster assets are eligible;
- generation attempts are capped at 2 per sync/render cycle;
- macOS uses `/usr/bin/sips` to produce disposable PNG thumbnails before GPUI sees an image path;
- generated thumbnail longest edge is bounded to 320 px;
- GPUI `img(...)` receives only generated thumbnail files, never a supported raster original from this path;
- RAW and unsupported formats remain explicit placeholder/fallback paths in M3;
- missing assets never enter thumbnail generation;
- cache keys incorporate source path, size, and modification time so changed sources naturally invalidate old keys;
- cache output is disposable system-temp state, not catalog authority.

This bounds the decoded GPUI image dimensions for the M3 browser path. It intentionally does not add RAW demosaic or new durable thumbnail persistence.

## Layout hardening

Review feedback identified that the first thumbnail slice did not reserve enough vertical room for image plus metadata.

Resolved behavior:

- Grid cards were increased from 104 px to 132 px;
- Filmstrip preview height was reduced to 22 px while retaining metadata;
- row stride derives from the updated Grid item height.

## CI and review evidence

Final PR #27 head:

`6b7e797db1b9e82079578e2b9cbcb02873cf2ddc`

Exact-head required workflows:

- CI #483 — success
- GPUI Production Shell #55 — success
- Full validation #93 — success

The two Codex review threads were resolved before merge:

- P1 — decode bounded-size thumbnails instead of originals
- P2 — allocate enough height for thumbnails and labels

An earlier iOS job failure was infrastructure-only (`subosito/flutter-action` manifest download/parse failure) and was superseded by the final exact-head green validation.

## M3 acceptance checklist

- [x] authoritative Filmstrip uses real catalog DTOs
- [x] Filmstrip is horizontally virtualized
- [x] authoritative Grid uses the same catalog DTOs
- [x] Grid is virtualized with bounded overscan
- [x] Grid and Filmstrip share stable asset-ID selection
- [x] selection survives refresh/filter when possible
- [x] raster browser thumbnails are pixel-bounded before GPUI decode
- [x] thumbnail generation is bounded per sync
- [x] RAW remains fallback-only; no new image-processing scope
- [x] no GPUI-specific durable catalog persistence
- [x] no GPUI-to-Hive coupling
- [x] final exact-head CI/GPUI/full-validation green
- [x] review threads resolved

## Deferred beyond M3

The following are deliberately not M3 requirements:

- RAW embedded-preview path exposed directly through the Rust authoritative read DTO;
- strict lifecycle eviction of GPUI's global decoded-image cache beyond bounded source dimensions;
- catalog/import mutations from GPUI;
- Rust-native authoritative persistence migration;
- Develop/image-processing migration;
- W4 physical D1-D8 desktop validation.

These remain follow-on work under M4+ or the parallel validation track.
