# Validation status

Generated on 2026-08-12.

## Completed in generation environment

- Required source files exist.
- No underscore is used in the deliverable ZIP filename.
- C ABI ownership paths were statically reviewed.
- Dart paths allocated by `toNativeUtf8()` are paired with `calloc.free()`.
- Rust strings returned through FFI are paired with `free_string_rust()`.
- Rust image buffers are copied before `free_image_buffer()`.
- Flutter UI contains a real `Image.memory(...)` render path.
- LUT parser validates `size^3` and implements eight-corner trilinear interpolation.
- README and VERIFY document embedded-preview behavior and non-features honestly.

## Not executable in generation environment

The generation container does not include Rust/Cargo, Dart, or Flutter SDK executables. Therefore this artifact does **not** claim that `cargo check`, `cargo test`, `flutter analyze`, or `flutter test` were executed here.

Run the commands in `VERIFY.md` on the target development machine before treating this as a release candidate.
