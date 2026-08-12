# Validation Status

## Fixed from user build log

- Removed unsupported `rawler` feature `deflate`; `rawler 0.6.0` exposes `clap`, `inspector`, and `samplecheck` according to Cargo's resolver output.
- Replaced Dart FFI native `Size` with `UintPtr` for Rust `usize`, eliminating the `dart:ffi` / `dart:ui` `Size` ambiguity and providing a valid native integer type for `lookupFunction`.
- Fixed `FilePicker.platform.saveFile` named argument from `fileName=` to `fileName:`.
- Added `test/widget_test.dart` using `NixinApp`, replacing the default Flutter template expectation of `MyApp`.

## Environment limitation

This generation environment does not have `cargo`, `dart`, or `flutter` installed, so it cannot honestly claim that `cargo check`, `flutter analyze`, or `flutter test` passed here. Run the commands in `VERIFY.md` on the target development machine.

## 2026-08-12 build-log fixes, round 2

Based on the user's real `cargo check` / `flutter test` output:

- Removed invalid `use rawler::rawsource::RawSource;` for rawler 0.6.0.
- Current embedded-preview path reads RAW container bytes with `std::fs::read()` and scans JPEG markers.
- Explicitly typed the sky flood-fill queue as `VecDeque<(u32, u32)>` and removed ambiguous integer wrapping/saturating calls.
- Reworked the Flutter body from a fixed `Column` into a `CustomScrollView` with `SliverFillRemaining`
  so the 800x600 widget-test viewport can scroll instead of reporting a bottom RenderFlex overflow.
- The user's preceding run reported `flutter analyze` as `No issues found!`.
- This environment does not provide Cargo/Flutter executables, so the updated archive still requires
  final validation on the user's development machine.
