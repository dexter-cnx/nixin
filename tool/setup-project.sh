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
  local cmd="$1"
  local hint="$2"
  command -v "$cmd" >/dev/null 2>&1 || fail "$cmd is required. $hint"
}

install_cargo_ndk() {
  if command -v cargo-ndk >/dev/null 2>&1; then
    log "cargo-ndk already installed"
    cargo-ndk --version
    return
  fi

  log "Installing cargo-ndk"
  cargo install cargo-ndk --locked
  command -v cargo-ndk >/dev/null 2>&1 || fail "cargo-ndk installation completed but cargo-ndk is not on PATH. Ensure ~/.cargo/bin is on PATH."
  cargo-ndk --version
}

setup_android() {
  install_cargo_ndk

  if command -v rustup >/dev/null 2>&1; then
    log "Ensuring Rust Android arm64 target is installed"
    rustup target add aarch64-linux-android
  else
    printf 'WARN: rustup was not found; cannot automatically add aarch64-linux-android.\n'
  fi

  log "Checking Android toolchain visibility"
  if [[ -n "${ANDROID_NDK_HOME:-}" ]]; then
    printf 'ANDROID_NDK_HOME=%s\n' "$ANDROID_NDK_HOME"
  elif [[ -n "${ANDROID_NDK_ROOT:-}" ]]; then
    printf 'ANDROID_NDK_ROOT=%s\n' "$ANDROID_NDK_ROOT"
  elif [[ -n "${ANDROID_HOME:-}" ]]; then
    printf 'ANDROID_HOME=%s\n' "$ANDROID_HOME"
    printf 'INFO: cargo-ndk can also use an NDK installed by the Android SDK.\n'
  else
    printf 'WARN: ANDROID_HOME / ANDROID_NDK_HOME / ANDROID_NDK_ROOT is not set.\n'
    printf '      Flutter may still discover the SDK automatically; verify with flutter doctor -v.\n'
  fi
}

log "Nixin Studio V8 project setup"

require_command flutter "Install Flutter and add it to PATH."
require_command cargo "Install Rust using rustup and add ~/.cargo/bin to PATH."
require_command rustc "Install Rust using rustup."

log "Tool versions"
flutter --version
cargo --version
rustc --version

case "$MODE" in
  all|--all)
    setup_android
    ;;
  android|--android)
    setup_android
    ;;
  common|--common)
    ;;
  *)
    fail "Unknown setup mode '$MODE'. Use: all, android, or common."
    ;;
esac

log "Fetching Rust dependencies"
(
  cd "$RUST_DIR"
  cargo fetch
)

log "Fetching Flutter dependencies"
(
  cd "$ROOT_DIR"
  flutter pub get
)

log "Running lightweight toolchain checks"
(
  cd "$RUST_DIR"
  cargo check
)
(
  cd "$ROOT_DIR"
  flutter analyze
)

log "Flutter doctor"
flutter doctor -v || true

printf '\nNixin project setup complete.\n'
printf 'Next recommended command: make validate\n'
