#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-preflight}"
EVIDENCE_ROOT="${W4_EVIDENCE_DIR:-build/w4-validation}"
FLUTTER_CMD="${FLUTTER_CMD:-flutter}"
CARGO_CMD="${CARGO_CMD:-cargo}"
STAMP="$(date +%Y%m%d-%H%M%S)"
EVIDENCE_DIR="${EVIDENCE_ROOT}/${STAMP}"
REPORT="${EVIDENCE_DIR}/environment.txt"

usage() {
  cat <<'EOF'
Usage: tool/w4-desktop-validation.sh [preflight|automated]

preflight   Record host/toolchain/repository information for a physical W4 run.
automated   Record the same information, then run W4-focused automated gates.

Environment:
  W4_EVIDENCE_DIR=<path>   Override evidence root (default: build/w4-validation).
  FLUTTER_CMD=<command>    Flutter command/path (default: flutter).
  CARGO_CMD=<command>      Cargo command/path (default: cargo).
EOF
}

case "$MODE" in
  preflight|automated) ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "ERROR: unknown mode '$MODE'" >&2
    usage >&2
    exit 2
    ;;
esac

mkdir -p "$EVIDENCE_DIR"

record_command() {
  local title="$1"
  shift
  {
    echo
    echo "== ${title} =="
    if command -v "$1" >/dev/null 2>&1; then
      "$@" 2>&1 || true
    else
      echo "NOT AVAILABLE: $1"
    fi
  } >>"$REPORT"
}

{
  echo "Dextryx Images W4 desktop validation evidence"
  echo "mode=${MODE}"
  echo "recorded_at=$(date -Iseconds 2>/dev/null || date)"
  echo "working_directory=$(pwd)"
  echo "git_commit=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  echo "flutter_command=${FLUTTER_CMD}"
  echo "cargo_command=${CARGO_CMD}"
  echo "git_status_begin"
  git status --short 2>/dev/null || true
  echo "git_status_end"
  echo "uname=$(uname -a 2>/dev/null || true)"
  if [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]]; then
    echo "macos_version=$(sw_vers -productVersion 2>/dev/null || true)"
    echo "macos_build=$(sw_vers -buildVersion 2>/dev/null || true)"
  fi
} >"$REPORT"

record_command "Flutter" "$FLUTTER_CMD" --version
record_command "Dart" dart --version
record_command "Rust" rustc --version
record_command "Cargo" "$CARGO_CMD" --version
record_command "Flutter devices" "$FLUTTER_CMD" devices
record_command "Disk usage" df -h

if [[ "$MODE" == "automated" ]]; then
  LOG="${EVIDENCE_DIR}/automated-gates.log"
  echo "Running W4 automated gates; output -> ${LOG}"
  {
    echo "== flutter analyze =="
    "$FLUTTER_CMD" analyze --fatal-infos

    echo
    echo "== focused Workplaces tests =="
    "$FLUTTER_CMD" test \
      test/workplaces/asset_browser_controller_test.dart \
      test/workplaces/import_controller_test.dart \
      test/workplaces/asset_thumbnail_cache_test.dart \
      test/workplaces/catalog_profile_test.dart

    echo
    echo "== Rust check/test =="
    (cd rust && "$CARGO_CMD" check && "$CARGO_CMD" test)
  } 2>&1 | tee "$LOG"

  {
    echo
    echo "automated_status=PASS"
    echo "automated_log=${LOG}"
  } >>"$REPORT"
fi

cat <<EOF
W4 validation evidence created:
  ${EVIDENCE_DIR}

Environment report:
  ${REPORT}
EOF
