#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="${NIXIN_BUNDLE_ID:-com.cnxdev.nixin}"
APPLE_TEAM="${NIXIN_APPLE_TEAM:-ZTM9BCJPY9}"

python3 - "$ROOT_DIR" "$BUNDLE_ID" "$APPLE_TEAM" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
bundle_id = sys.argv[2]
team = sys.argv[3]


def replace_file(path: Path, replacements):
    if not path.exists():
        return
    text = path.read_text()
    original = text
    for old, new in replacements:
        text = text.replace(old, new)
    if text != original:
        path.write_text(text)
        print(f"updated {path.relative_to(root)}")
    else:
        print(f"ok      {path.relative_to(root)}")

# Android application id / namespace.
replace_file(
    root / "android/app/build.gradle.kts",
    [
        ('com.example.nixin_studio_v8', bundle_id),
        ('com.example.nixinStudioV8', bundle_id),
    ],
)

# iOS Runner + RunnerTests and signing team.
ios_project = root / "ios/Runner.xcodeproj/project.pbxproj"
if ios_project.exists():
    text = ios_project.read_text()
    original = text
    text = text.replace('com.example.nixinStudioV8.RunnerTests', f'{bundle_id}.RunnerTests')
    text = text.replace('com.example.nixinStudioV8', bundle_id)
    text = text.replace('VRL8N6A823', team)
    # Keep the canonical team if a different explicit team is left in Runner configs.
    text = re.sub(r'DEVELOPMENT_TEAM = [A-Z0-9]{10};', f'DEVELOPMENT_TEAM = {team};', text)
    if text != original:
        ios_project.write_text(text)
        print(f"updated {ios_project.relative_to(root)}")
    else:
        print(f"ok      {ios_project.relative_to(root)}")

# macOS uses AppInfo.xcconfig for the app bundle id, while tests keep their
# bundle id in project.pbxproj. Normalize both and any explicit team setting.
replace_file(
    root / "macos/Runner/Configs/AppInfo.xcconfig",
    [
        ('com.example.nixinStudioV8', bundle_id),
        ('Copyright © 2026 com.example.', 'Copyright © 2026 CNXDev.'),
    ],
)

macos_project = root / "macos/Runner.xcodeproj/project.pbxproj"
if macos_project.exists():
    text = macos_project.read_text()
    original = text
    text = text.replace('com.example.nixinStudioV8.RunnerTests', f'{bundle_id}.RunnerTests')
    text = text.replace('com.example.nixinStudioV8', bundle_id)
    text = re.sub(r'DEVELOPMENT_TEAM = [A-Z0-9]{10};', f'DEVELOPMENT_TEAM = {team};', text)
    if text != original:
        macos_project.write_text(text)
        print(f"updated {macos_project.relative_to(root)}")
    else:
        print(f"ok      {macos_project.relative_to(root)}")

print(f"bundle id : {bundle_id}")
print(f"Apple team: {team}")
PY

# Verify Android Kotlin package location/content when present.
MAIN_ACTIVITY="$ROOT_DIR/android/app/src/main/kotlin/com/cnxdev/nixin/MainActivity.kt"
if [[ -f "$MAIN_ACTIVITY" ]]; then
  grep -q '^package com\.cnxdev\.nixin$' "$MAIN_ACTIVITY" || {
    echo "ERROR: MainActivity package does not match com.cnxdev.nixin" >&2
    exit 1
  }
fi

printf '\nNixin identifiers configured.\n'
