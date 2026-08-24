#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FLUTTER_CMD="${FLUTTER_CMD:-flutter}"
CARGO_CMD="${CARGO_CMD:-cargo}"

echo "== Dart format =="
if command -v "$FLUTTER_CMD" >/dev/null 2>&1; then
  dart format lib test
else
  echo "ERROR: Flutter/Dart toolchain not found" >&2
  exit 1
fi

echo
echo "== Rust format: raw-engine =="
"$CARGO_CMD" fmt --manifest-path rust/Cargo.toml

echo
echo "== Rust format: shared crates =="
"$CARGO_CMD" fmt --manifest-path crates/Cargo.toml --all

echo
echo "== Rust format: GPUI desktop =="
"$CARGO_CMD" fmt --manifest-path experiments/gpui-desktop/Cargo.toml

echo
echo "Formatting complete."
