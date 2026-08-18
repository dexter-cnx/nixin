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

### macOS bundle

```bash
make gpui-s4-macos-bundle
open "build/gpui-s4/Dextryx Images GPUI.app"
```

The spike bundle deliberately uses:

```text
com.cnxdev.dextryx.images.gpui-spike
```

so it does not collide with the production Dextryx Images application identifier. The generated S4 bundle is intentionally unsigned; signing/notarization is a later production-distribution concern, not required to prove the GPUI packaging boundary.

### Windows

Run from Git Bash/MSYS2:

```bash
make gpui-s4-check
```

Or from PowerShell, from `experiments/gpui-desktop`:

```powershell
cargo test --locked --test catalog_boundary
cargo build --locked --release
.\target\release\dextryx-gpui-spike.exe
```

Windows physical smoke must verify:

- application launches;
- text/glyphs render correctly;
- native file dialog opens;
- raster/current RAW-preview file can be opened;
- direct raw-engine viewport displays correctly;
- pan/zoom works;
- 5,000-asset Filmstrip remains responsive;
- background thumbnail work remains bounded;
- Catalog switching remains responsive.

### Linux

From repository root:

```bash
make gpui-s4-check
```

The S4 script explicitly builds with:

```text
gpui_platform/wayland,gpui_platform/x11
```

Linux physical smoke must verify under a real desktop session:

- application launches under Wayland or X11;
- text renders;
- file dialog opens;
- viewport and Filmstrip work;
- no obvious backend-specific input/scroll regression.

If the first Linux feature-enabled resolution changes `experiments/gpui-desktop/Cargo.lock`, review and commit that lockfile delta separately before claiming deterministic Linux builds.

## S4 scorecard

| Gate | Status | Evidence |
|---|---|---|
| macOS release compile | Pending | `make gpui-s4-check` |
| macOS `.app` bundle creation | Pending | `make gpui-s4-macos-bundle` |
| macOS `.app` launch | Pending | Physical smoke |
| macOS file dialog | Pending | Physical smoke |
| macOS viewport/Filmstrip regression smoke | Pending | Physical smoke |
| Windows release compile | Pending | Windows host |
| Windows launch + text | Pending | Windows physical smoke |
| Windows file dialog | Pending | Windows physical smoke |
| Windows viewport/Filmstrip | Pending | Windows physical smoke |
| Linux release compile | Pending | Linux host |
| Linux launch | Pending | Linux desktop smoke |
| Linux file dialog/viewport/Filmstrip | Pending | Linux desktop smoke |
| pinned-revision maintenance assessment | Pending | Controlled upgrade experiment |

## S4 pass rule

Do not mark S4 globally PASS from macOS alone.

Minimum evidence for the final migration decision:

1. macOS release bundle builds and launches with no S0-S3 regression;
2. Windows compiles and physically launches with text, file dialog, viewport, and Filmstrip working;
3. Linux compiles and at least one Linux desktop backend launches successfully;
4. a controlled GPUI pin-update experiment quantifies source churn rather than assuming dependency upgrades are cheap.

A platform failure does not automatically mean GPUI must be abandoned. The final S5 decision may choose a narrower supported-platform policy, but that tradeoff must be explicit.
