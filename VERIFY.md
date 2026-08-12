# Nixin Studio V8 Verification

## Build gates

```bash
cd rust
cargo check
cargo test

cd ..
flutter create . --platforms=android,ios,macos,windows,linux
flutter pub get
flutter analyze
flutter test
```

## Fix verification

- Allocator ownership: inspect `lib/main.dart`; every `toNativeUtf8()` is paired with `calloc.free()`. Rust strings use `free_string_rust()`.
- Image lifetime: `RawEngine._copyBuffer()` copies bytes with `Uint8List.fromList(...)` before `free_image_buffer()`.
- Buffer metadata: Flutter verifies `len == width * height * 4`; Rust getters return zero/null for null handles.
- Version signature: `get_v7_version()` has zero arguments in Rust and Dart.
- Last error: Rust allocates a CString; Dart converts it then calls `free_string_rust()`.
- Subject bounds: Rust rejects negative or >= width/height click coordinates with `"Click outside"`.
- Subject mask: flood fill uses RGB Manhattan distance < 70; no-click path compares border-average brightness by threshold 22.
- Sky mask: blue + overcast candidate detection, vertical prior, and top-connected flood fill.
- LUT title: quoted `TITLE "Kodak 2383"` is unquoted during parsing.
- LUT domain: `DOMAIN_MIN/MAX` are parsed but documented as not applied in V8.
- LUT data length: parser requires exactly `size^3` entries.
- LUT interpolation: `sample_lut_trilinear()` samples 8 corners and lerps R, then G, then B axes.
- LUT strength: rejects NaN/Infinity and clamps finite values to 0..1.
- JPEG quality: `JpegEncoder::new_with_quality` is used with quality clamped to 1..100.
- Export default: `ExportOptions::default().quality == 90`.
- XML escaping: `& < > \" '` are escaped.
- XMP structure: generated sidecar includes `x:xmpmeta`, RDF, `rdf:Description`, and XMP namespace.
- XMP conditional: sidecar is written only if rating or label is `Some` in the Rust core API.
- XMP errors: file creation/write errors are propagated.
- Real UI image: `rgbaToPng()` converts the copied RGBA buffer and `Image.memory(png!)` renders it.
- File picker: RAW extension list is exactly ARW/CR2/CR3/NEF/DNG/RAF/ORF.
- `check_engine()`: README documents the limited scope of the check.
- Watched-folder terminology: README explicitly states this is not USB/PTP tethered shooting.

## Rust tests included

- `test_lut_identity`
- `test_lut_trilinear`
- `test_subject_oob`
- `test_jpeg_quality`
- `test_xmp_escape`
- `test_ffi_buffer`

## Flutter test included

- `test/ffi_smoke_test.dart`

The Flutter smoke test intentionally checks packaging expectations only unless CI provides a compiled native library and RAW fixture. Claiming a real develop smoke without those artifacts would be misleading.

## rawler 0.6 compatibility note

`rawler = "0.6"` is retained in `Cargo.toml`, but V8's preview-only implementation does **not**
import the non-existent `rawler::rawsource::RawSource` API. The current path reads file bytes with
`std::fs::read()` and scans for embedded JPEGs. This is intentionally documented as preview extraction,
not RAW debayering.
