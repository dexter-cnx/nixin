# Nixin Studio V8

A Flutter + Rust photo-editor foundation that scans camera RAW container bytes for the **embedded JPEG preview** and returns a real RGBA image buffer over C FFI.

## What it is

- Working Rust embedded-preview processor.
- Functional Dart FFI bridge with explicit allocator ownership.
- Real image display in Flutter (`Image.memory` after RGBA→PNG conversion).
- Exposure, simple temperature RGB scaling, and contrast.
- Heuristic subject and sky masks.
- `.cube` 3D LUT with true trilinear interpolation.
- JPEG export with quality 1–100.
- Basic XMP sidecar generation when metadata is provided through the Rust core API.

## What it is not

This is **not** a full RAW developer. It does not currently debayer sensor mosaics, perform camera color transforms, lens correction, highlight recovery, GPU processing, real SAM/ONNX inference, USB/PTP tethered shooting, or production batch processing.

## Architecture

```text
Flutter UI
  │
  ├─ Dart FFI (ffi.dart logic in lib/main.dart)
  │    ├─ Dart strings allocated with calloc → Dart frees
  │    ├─ Rust strings → Rust free_string_rust
  │    └─ Rust ImageBuffer → copy bytes → free_image_buffer
  │
  ▼
Rust C ABI (rust/src/lib.rs)
  │
  ▼
Rust core (rust/src/api.rs)
  │
  ├─ std::fs reads RAW container bytes for the current preview-only path
  ├─ embedded JPEG scanner selects the largest decodable JPEG preview
  └─ rawler dependency is retained for future real RAW decoding work; V8 does not claim to debayer
  ├─ image crate decodes/encodes JPEG/PNG
  └─ CPU develop/mask/LUT/export operations
```

## Supported picker extensions

ARW, CR2, CR3, NEF, DNG, RAF, ORF.

Support in practice depends on the file containing an embedded JPEG that the scanner can locate and the `image` crate can decode.

## Limitations

1. Uses an embedded JPEG preview, not RAW sensor debayering.
2. Some RAW containers may use preview layouts that the JPEG marker scanner does not locate reliably.
3. Exposure is applied to 8-bit preview pixels, so highlight latitude is limited.
4. Temperature uses simple red/blue scaling, not a chromatic-adaptation transform.
5. Tint is not implemented.
6. Shadows/highlights/whites/blacks are not implemented.
7. Subject mask is heuristic flood-fill/brightness segmentation, not AI.
8. Sky mask can false-positive on white ceilings, bright buildings, blue objects, and unusual lighting.
9. `.cube` `DOMAIN_MIN`/`DOMAIN_MAX` are parsed but V8 sampling assumes normalized 0–1 input.
10. No GPU path, USB/PTP tethering, real batch queue, color-managed monitor pipeline, or embedded XMP-in-JPEG writer yet.

## Build

```bash
cd nixin-full-source
flutter create . --platforms=android,ios,macos,windows,linux

cd rust
cargo check
cargo test
cargo build --release
cd ..

flutter pub get
flutter analyze
flutter test
flutter run
```

### Desktop native library

After `cargo build --release`, copy the produced library where the executable can load it:

- macOS: `rust/target/release/libraw_engine.dylib`
- Linux: `rust/target/release/libraw_engine.so`
- Windows: `rust/target/release/raw_engine.dll`

For a production Flutter desktop app, bundle the native library in the platform runner instead of relying on the current working directory.

### Android

Build with `cargo-ndk` for each ABI and place libraries under:

```text
android/app/src/main/jniLibs/arm64-v8a/libraw_engine.so
android/app/src/main/jniLibs/armeabi-v7a/libraw_engine.so
android/app/src/main/jniLibs/x86_64/libraw_engine.so
```

Only ship ABIs you actually build and test.

### iOS

`DynamicLibrary.process()` requires the Rust symbols to be linked into the app process, typically via a static library/XCFramework integration. This ZIP does not claim that Xcode integration has already been generated.

## FFI ownership rules

- Dart `toNativeUtf8()` → `calloc.free()` in Dart after the Rust call returns.
- Rust `CString::into_raw()` → `free_string_rust()` only.
- Rust `Box<ImageBuffer>` → Dart copies `len` bytes → `free_image_buffer()`.
- Buffer getters are null-safe.
- Flutter validates `len == width * height * 4` before copying.
- Rust catches panics at image-returning FFI boundaries and reports `LAST_ERROR`.

## check_engine()

`check_engine()` verifies only that the library is loaded and the internal error mutex is usable. It does **not** validate RAW decoding, platform packaging, filesystem permissions, AI, or GPU support.

## Watched folder import

The Rust core includes `TetheredWatcher::check_new_files(known)` semantics, but this is a **watched-folder importer**, not tethered shooting. USB/PTP camera control is not implemented.
