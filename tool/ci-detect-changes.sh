#!/usr/bin/env bash
set -euo pipefail

BASE_SHA="${1:-}"
HEAD_SHA="${2:-HEAD}"
OUTPUT_FILE="${GITHUB_OUTPUT:-/dev/stdout}"

if [[ -z "$BASE_SHA" || "$BASE_SHA" == "0000000000000000000000000000000000000000" ]]; then
  BASE_SHA="$(git rev-parse "${HEAD_SHA}^")"
fi

if ! git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
  echo "Base commit $BASE_SHA is unavailable; conservatively enabling broad CI." >&2
  CHANGED_FILES=".github/workflows/ci.yml"
else
  CHANGED_FILES="$(git diff --name-only "$BASE_SHA" "$HEAD_SHA")"
fi

set_output() {
  printf '%s=%s\n' "$1" "$2" >> "$OUTPUT_FILE"
}

has_match() {
  local pattern="$1"
  grep -Eq "$pattern" <<<"$CHANGED_FILES"
}

DOCS=false
FLUTTER=false
RUST=false
FFI=false
PLATFORM_ANDROID=false
PLATFORM_IOS=false
PLATFORM_MACOS=false
PLATFORM_WINDOWS=false
PLATFORM_LINUX=false
IMPORT_FILESYSTEM=false
EXPORT_ENGINE=false
CI=false

has_match '(^|/)(README|CHANGELOG|CONTRIBUTING)(\.md)?$|\.md$|^docs/' && DOCS=true
has_match '^lib/|^test/|^integration_test/|^pubspec\.(yaml|lock)$|^analysis_options\.yaml$|^assets/' && FLUTTER=true
has_match '^rust/|(^|/)Cargo\.(toml|lock)$' && RUST=true
has_match '^lib/engine/|^rust/src/(api|lib)\.rs$|flutter_rust_bridge|frb|bindings|bridge|ffi' && FFI=true
has_match '^android/' && PLATFORM_ANDROID=true
has_match '^ios/' && PLATFORM_IOS=true
has_match '^macos/' && PLATFORM_MACOS=true
has_match '^windows/' && PLATFORM_WINDOWS=true
has_match '^linux/' && PLATFORM_LINUX=true
has_match '^lib/workplaces/|^test/workplaces/|import|file_picker|filesystem|file-system|storage|catalog|workplace' && IMPORT_FILESYSTEM=true
has_match '^lib/engine/|^rust/|export|lut|mask|develop_settings|developsettings|image_engine|raw_engine' && EXPORT_ENGINE=true
has_match '^\.github/workflows/|^Makefile$|^project\.mk$|^tool/ci-|^tool/.*\.sh$' && CI=true

DOCS_ONLY=true
if [[ -z "$CHANGED_FILES" ]]; then
  DOCS_ONLY=false
else
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ ! "$file" =~ ^docs/ && ! "$file" =~ \.md$ ]]; then
      DOCS_ONLY=false
      break
    fi
  done <<<"$CHANGED_FILES"
fi

# Docs-only is authoritative. Keyword-like documentation filenames such as
# CATALOG or EXPORT must never activate product/native domains.
if [[ "$DOCS_ONLY" == true ]]; then
  FLUTTER=false
  RUST=false
  FFI=false
  PLATFORM_ANDROID=false
  PLATFORM_IOS=false
  PLATFORM_MACOS=false
  PLATFORM_WINDOWS=false
  PLATFORM_LINUX=false
  IMPORT_FILESYSTEM=false
  EXPORT_ENGINE=false
  CI=false
fi

# CI/build-system changes are intentionally conservative because they can alter
# which validation runs at all.
BROAD=false
if [[ "$CI" == true ]]; then
  BROAD=true
  FLUTTER=true
  RUST=true
  FFI=true
  PLATFORM_ANDROID=true
  PLATFORM_IOS=true
  PLATFORM_MACOS=true
  PLATFORM_WINDOWS=true
  PLATFORM_LINUX=true
  IMPORT_FILESYSTEM=true
  EXPORT_ENGINE=true
fi

set_output docs "$DOCS"
set_output docs_only "$DOCS_ONLY"
set_output flutter "$FLUTTER"
set_output rust "$RUST"
set_output ffi "$FFI"
set_output platform_android "$PLATFORM_ANDROID"
set_output platform_ios "$PLATFORM_IOS"
set_output platform_macos "$PLATFORM_MACOS"
set_output platform_windows "$PLATFORM_WINDOWS"
set_output platform_linux "$PLATFORM_LINUX"
set_output import_filesystem "$IMPORT_FILESYSTEM"
set_output export_engine "$EXPORT_ENGINE"
set_output ci "$CI"
set_output broad "$BROAD"

printf 'Changed files:\n%s\n' "$CHANGED_FILES"
