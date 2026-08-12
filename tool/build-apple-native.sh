#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUST_DIR="$ROOT_DIR/rust"
MODE="${1:-all}"

log() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf '\nERROR: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

require_apple_host() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "Apple native builds require macOS"
  require_command cargo
  require_command rustup
  require_command xcrun
  require_command lipo
}

ensure_targets() {
  rustup target add \
    aarch64-apple-darwin \
    x86_64-apple-darwin \
    aarch64-apple-ios \
    aarch64-apple-ios-sim \
    x86_64-apple-ios
}

build_macos() {
  log "Building macOS universal static library"
  mkdir -p "$ROOT_DIR/macos/Native"

  (
    cd "$RUST_DIR"
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
  )

  lipo -create \
    "$RUST_DIR/target/aarch64-apple-darwin/release/libraw_engine.a" \
    "$RUST_DIR/target/x86_64-apple-darwin/release/libraw_engine.a" \
    -output "$ROOT_DIR/macos/Native/libraw_engine.a"

  lipo -info "$ROOT_DIR/macos/Native/libraw_engine.a"
}

build_ios() {
  log "Building iOS device + simulator static libraries"
  mkdir -p "$ROOT_DIR/ios/Native/device" "$ROOT_DIR/ios/Native/simulator"

  (
    cd "$RUST_DIR"
    cargo build --release --target aarch64-apple-ios
    cargo build --release --target aarch64-apple-ios-sim
    cargo build --release --target x86_64-apple-ios
  )

  cp \
    "$RUST_DIR/target/aarch64-apple-ios/release/libraw_engine.a" \
    "$ROOT_DIR/ios/Native/device/libraw_engine.a"

  lipo -create \
    "$RUST_DIR/target/aarch64-apple-ios-sim/release/libraw_engine.a" \
    "$RUST_DIR/target/x86_64-apple-ios/release/libraw_engine.a" \
    -output "$ROOT_DIR/ios/Native/simulator/libraw_engine.a"

  printf 'Device: '
  lipo -info "$ROOT_DIR/ios/Native/device/libraw_engine.a"
  printf 'Simulator: '
  lipo -info "$ROOT_DIR/ios/Native/simulator/libraw_engine.a"
}

require_apple_host
ensure_targets

case "$MODE" in
  all|--all)
    build_macos
    build_ios
    ;;
  macos|--macos)
    build_macos
    ;;
  ios|--ios)
    build_ios
    ;;
  *)
    fail "Unknown mode '$MODE'. Use: all, macos, or ios."
    ;;
esac

printf '\nApple native build complete.\n'
