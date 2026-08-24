#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FLUTTER_CMD="${FLUTTER_CMD:-flutter}"
CARGO_CMD="${CARGO_CMD:-cargo}"
RUSTFMT_CMD="${RUSTFMT_CMD:-rustfmt}"

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

# main.rs is included from src/entry.rs and is not discovered by cargo fmt.
# Keep this explicit rustfmt guard aligned with ci-rust-format-check.sh so
# pre-push formatting cannot diverge from the CI changed-file format gate.
"$RUSTFMT_CMD" --edition 2021 experiments/gpui-desktop/src/main.rs

echo
echo "Formatting complete."
