#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

make format

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo >&2
  echo "Pre-push stopped: formatter changed tracked files." >&2
  echo "Review and commit the formatting changes, then run make pre-push again." >&2
  exit 1
fi

make ci-fast
