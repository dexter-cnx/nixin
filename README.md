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
  ├─ Dart FFI (logic currently in lib/main.dart)
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
  ├─ rawler dependency is retained for future real RAW decoding work; V8 does not claim to debayer
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

## Project setup

Prerequisites that must already be installed and available on `PATH`:

- Flutter SDK
- Rust toolchain (`cargo`, `rustc`, `rustup`)
- Android SDK/NDK for Android native builds
- Xcode + command line tools for macOS/iOS builds

Bootstrap the current host with:

```bash
make setup
```

On macOS, `make setup` prepares both Android and Apple Rust targets. It will:

1. Verify Flutter and Rust.
2. Install `cargo-ndk` if missing.
3. Add the Android `aarch64-linux-android` Rust target.
4. Add macOS/iOS Rust targets for Apple Silicon, Intel macOS, physical iOS, and iOS simulators.
5. Verify Xcode tools.
6. Run `cargo fetch`, `flutter pub get`, `cargo check`, and `flutter analyze`.
7. Print `flutter doctor -v`.

Useful setup targets:

```bash
make setup-common
make setup-android
make setup-apple
make bootstrap
```

## Validation

Run the full local validation gate:

```bash
make validate
```

Equivalent commands are:

```bash
flutter pub get
cd rust
cargo check
cargo test
cd ..
flutter analyze
flutter test
```

## Android

Build the currently validated Android ABI:

```bash
make android-arm64
```

Output:

```text
android/app/src/main/jniLibs/arm64-v8a/libraw_engine.so
```

Build Rust and run Flutter on an Android device:

```bash
make run-android DEVICE=<flutter-device-id>
```

## macOS

Apple platforms use the Rust `staticlib` output and link it into the Runner. Dart opens the process itself with `DynamicLibrary.process()`.

Build a universal macOS static archive (`arm64 + x86_64`):

```bash
make macos-native
```

Generated artifact:

```text
macos/Native/libraw_engine.a
```

The generated archive is ignored by Git. Xcode links it through `macos/Flutter/Native-Rust.xcconfig` with `-force_load` so FFI entry points are not dead-stripped.

Build native Rust and run the macOS Flutter app:

```bash
make run-macos
```

## iOS

The iOS build produces separate archives for device and simulator:

```bash
make ios-native
```

Generated artifacts:

```text
ios/Native/device/libraw_engine.a
ios/Native/simulator/libraw_engine.a
```

Device archive:

```text
aarch64-apple-ios
```

Simulator archive is universal where supported:

```text
aarch64-apple-ios-sim + x86_64-apple-ios
```

Xcode selects the proper archive through `ios/Flutter/Native-Rust.xcconfig` and force-loads it into Runner. Dart then resolves the exported C ABI symbols through `DynamicLibrary.process()`.

Validate iOS native linkage without code signing:

```bash
make ios-build-nosign
```

Run on a physical iPhone or simulator:

```bash
flutter devices
make run-ios DEVICE=<flutter-device-id>
```

For example, use the exact device ID printed by `flutter devices`; the Makefile intentionally does not hard-code a personal device identifier.

## Apple native build script

Both Apple platforms are built by:

```text
tool/build-apple-native.sh
```

Direct modes:

```bash
bash tool/build-apple-native.sh macos
bash tool/build-apple-native.sh ios
bash tool/build-apple-native.sh all
```

Or through Make:

```bash
make macos-native
make ios-native
make apple-native
```

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
