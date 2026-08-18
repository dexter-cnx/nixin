#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPIKE_DIR="$ROOT_DIR/experiments/gpui-desktop"
DIST_DIR="$ROOT_DIR/build/gpui-s4"
APP_NAME="${GPUI_APP_NAME:-Dextryx Images GPUI}"
BUNDLE_ID="${GPUI_BUNDLE_ID:-com.cnxdev.dextryx.images.gpui-spike}"
BINARY_NAME="dextryx-gpui-spike"

usage() {
  cat <<'EOF'
Usage: tool/gpui-s4-validation.sh <check|macos-bundle>

  check         Run S3 contract tests and a release build for the current host.
  macos-bundle  Build a release binary and package a minimal macOS .app bundle.

Environment overrides:
  GPUI_APP_NAME   macOS bundle display name (default: Dextryx Images GPUI)
  GPUI_BUNDLE_ID  macOS bundle identifier (default: com.cnxdev.dextryx.images.gpui-spike)
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

host_name() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux) echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

check_host() {
  require_cmd cargo
  local host
  host="$(host_name)"

  echo "== GPUI S4 host validation =="
  echo "host=$host"
  echo "rustc=$(rustc --version)"
  echo "cargo=$(cargo --version)"
  echo

  cd "$SPIKE_DIR"

  echo "== S3 repository contract =="
  cargo test --locked --test catalog_boundary

  echo
  echo "== GPUI release compile =="
  cargo build --locked --release

  echo
  echo "GPUI S4 host compile PASS ($host)"

  case "$host" in
    macos)
      echo "Next: make gpui-s4-macos-bundle"
      ;;
    linux)
      echo "Next: launch ./target/release/$BINARY_NAME under a desktop session and smoke file dialog, viewport, and Filmstrip."
      ;;
    windows)
      echo "Next: launch target\\release\\${BINARY_NAME}.exe and smoke text, file dialog, viewport, and Filmstrip."
      ;;
    *)
      echo "WARNING: S4 launch semantics are not defined for this host."
      ;;
  esac
}

macos_bundle() {
  if [[ "$(host_name)" != "macos" ]]; then
    echo "ERROR: macos-bundle requires macOS" >&2
    exit 1
  fi

  require_cmd cargo
  require_cmd plutil

  cd "$SPIKE_DIR"
  cargo build --locked --release

  local source_binary="$SPIKE_DIR/target/release/$BINARY_NAME"
  local app_dir="$DIST_DIR/${APP_NAME}.app"
  local contents_dir="$app_dir/Contents"
  local macos_dir="$contents_dir/MacOS"
  local resources_dir="$contents_dir/Resources"
  local destination_binary="$macos_dir/$BINARY_NAME"

  test -x "$source_binary" || {
    echo "ERROR: release binary not found: $source_binary" >&2
    exit 1
  }

  rm -rf "$app_dir"
  mkdir -p "$macos_dir" "$resources_dir"
  cp "$source_binary" "$destination_binary"
  chmod +x "$destination_binary"

  cat > "$contents_dir/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${BINARY_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

  plutil -lint "$contents_dir/Info.plist"

  echo
  echo "Created macOS app bundle:"
  echo "$app_dir"
  echo
  echo "Launch with:"
  printf 'open %q\n' "$app_dir"
  echo
  echo "This spike bundle is intentionally unsigned and uses a non-production bundle id."
}

case "${1:-}" in
  check) check_host ;;
  macos-bundle) macos_bundle ;;
  *) usage; exit 2 ;;
esac
