#!/usr/bin/env bash
set -euo pipefail

BASE_SHA="${1:-}"
HEAD_SHA="${2:-HEAD}"

if [[ -z "$BASE_SHA" ]]; then
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    BASE_SHA="$(git merge-base "$HEAD_SHA" origin/main)"
  elif git rev-parse --verify "${HEAD_SHA}^" >/dev/null 2>&1; then
    BASE_SHA="$(git rev-parse "${HEAD_SHA}^")"
  else
    echo "No comparison base available; no committed Rust delta to check."
    BASE_SHA="$HEAD_SHA"
  fi
fi

changed_files="$({
  git diff --name-only --diff-filter=ACMR "$BASE_SHA" "$HEAD_SHA" -- 'rust/**/*.rs' 'rust/*.rs'
  git diff --name-only --diff-filter=ACMR -- 'rust/**/*.rs' 'rust/*.rs'
  git diff --cached --name-only --diff-filter=ACMR -- 'rust/**/*.rs' 'rust/*.rs'
} | sort -u)"

files=()
while IFS= read -r file; do
  [[ -z "$file" || ! -f "$file" ]] && continue
  files+=("$file")
done <<<"$changed_files"

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No changed Rust source files to format-check."
  exit 0
fi

printf 'Rust format-check files:\n'
printf '  %s\n' "${files[@]}"
rustfmt --edition 2021 --check "${files[@]}"
