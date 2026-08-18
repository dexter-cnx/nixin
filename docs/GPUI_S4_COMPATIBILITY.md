# Dextryx Images — GPUI S4 Desktop Compatibility

S4 validates desktop compatibility and packaging only. It does not authorize a production persistence migration, additional feature-port families, Flutter desktop removal, or RAW demosaic work.

Pinned GPUI/Zed revision:

```text
fd90c0af7f021d89e511dd9a5f92d4f04ec29314
```

## Upstream platform facts at the pinned revision

The pinned `gpui_platform` crate has target-specific backends for macOS, Windows, Linux/FreeBSD, and web. The pinned GPUI README documents:

- macOS: Metal rendering; `font-kit` is required for glyph rasterization;
- Linux/FreeBSD: at least one of `wayland` or `x11` must be enabled;
- Windows: Win32 windowing + DirectWrite text; no GPUI platform feature is required;
- GPUI remains pre-1.0 and may introduce breaking changes between revisions;
- latest stable Rust is expected.

The Zed workspace pins `gpui_linux` with `default-features = false`, so the S4 Linux build explicitly enables both `gpui_platform/wayland` and `gpui_platform/x11`.

## Reproducible validation commands

From repository root:

```bash
make gpui-s4-check
```

This runs the S3 catalog contract and a release build for the current host.

### macOS bundle — PASS on physical macOS

Validated on the user's Mac:

```bash
make gpui-s4-check
make gpui-s4-macos-bundle
open "build/gpui-s4/Dextryx Images GPUI.app"
```

Observed PASS:

- release compile succeeds;
- the unsigned `.app` bundle is created successfully;
- the `.app` launches outside `cargo run`;
- text renders correctly;
- native `Open Image` file dialog works;
- direct raw-engine viewport still displays correctly;
- pan/zoom remains functional;
- 5,000-asset Filmstrip remains responsive;
- Catalog switching remains responsive.

The spike bundle deliberately uses:

```text
com.cnxdev.dextryx.images.gpui-spike
```

so it does not collide with the production Dextryx Images application identifier. Signing/notarization remains a later production-distribution concern.

## Windows and Linux without physical machines

The current development environment has no physical Windows or Linux machine available. S4 therefore separates **CI compile evidence** from **physical interactive evidence**.

Dedicated workflow:

```text
.github/workflows/gpui-s4.yml
```

`GPUI S4 Compatibility` runs only for the GPUI spike branch (or manual dispatch) and does not add cost/latency to normal production CI. It provides:

- Windows `cargo test --locked --test catalog_boundary`;
- Windows release compile and executable existence check;
- Linux catalog contract test;
- Linux release compile with `gpui_platform/wayland,gpui_platform/x11`;
- Linux executable existence check;
- Linux native packages based on the pinned Zed Linux dependency guidance.

A green CI job proves that the project and pinned GPUI backend compile on that runner. It does **not** prove text rendering, window behavior, native dialogs, input, viewport presentation, or Filmstrip responsiveness on a real Windows/Linux desktop session.

### Windows physical smoke — deferred, not failed

When a Windows machine becomes available, validate:

- application launches;
- text/glyphs render correctly;
- native file dialog opens;
- raster/current RAW-preview file can be opened;
- direct raw-engine viewport displays correctly;
- pan/zoom works;
- 5,000-asset Filmstrip remains responsive;
- background thumbnail work remains bounded;
- Catalog switching remains responsive.

### Linux physical smoke — deferred, not failed

When a Linux desktop becomes available, validate under Wayland or X11:

- application launches;
- text renders;
- file dialog opens;
- viewport and Filmstrip work;
- no obvious backend-specific input/scroll regression.

## S4 scorecard

| Gate | Status | Evidence |
|---|---|---|
| macOS release compile | PASS | `make gpui-s4-check`, physical macOS |
| macOS `.app` bundle creation | PASS | `make gpui-s4-macos-bundle` |
| macOS `.app` launch | PASS | Physical smoke |
| macOS file dialog | PASS | Physical smoke |
| macOS viewport/Filmstrip regression smoke | PASS | Physical smoke |
| Windows release compile | CI pending | `GPUI S4 Compatibility` workflow |
| Windows launch + text | Deferred | No physical Windows machine available |
| Windows file dialog | Deferred | No physical Windows machine available |
| Windows viewport/Filmstrip | Deferred | No physical Windows machine available |
| Linux release compile | CI pending | `GPUI S4 Compatibility` workflow |
| Linux launch | Deferred | No physical Linux desktop available |
| Linux file dialog/viewport/Filmstrip | Deferred | No physical Linux desktop available |
| pinned-revision maintenance assessment | Pending | Controlled upgrade experiment |

## S4 interpretation rule

Do not label Windows or Linux **physically validated** from CI alone.

For the architecture decision, distinguish these evidence levels:

```text
physical PASS      macOS interaction + packaging verified on real hardware
CI compile PASS    platform backend compiles on hosted runner
DEFERRED           interactive desktop behavior not tested because hardware is unavailable
FAIL               an attempted required gate actually failed
```

Unavailable hardware is a deferred evidence item, not a platform failure.

A final S5 decision may proceed with an explicit macOS-first support policy if Windows/Linux CI compiles cleanly and the remaining uncertainty is accepted, but it must not claim production Windows/Linux support until their interactive smoke gates are eventually run.
