#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${APP_ID:?APP_ID is required; run through make or export it explicitly}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required; run through make or export it explicitly}"
: "${ANDROID_APPLICATION_ID:=$APP_ID}"
: "${ANDROID_NAMESPACE:=$APP_ID}"
: "${IOS_BUNDLE_ID:=$APP_ID}"
: "${MACOS_BUNDLE_ID:=$APP_ID}"
: "${TEST_BUNDLE_SUFFIX:=RunnerTests}"

python3 - \
  "$ROOT_DIR" \
  "$ANDROID_APPLICATION_ID" \
  "$ANDROID_NAMESPACE" \
  "$IOS_BUNDLE_ID" \
  "$MACOS_BUNDLE_ID" \
  "$APPLE_TEAM_ID" \
  "$TEST_BUNDLE_SUFFIX" <<'PY'
from pathlib import Path
import re
import shutil
import sys

root = Path(sys.argv[1])
android_app_id = sys.argv[2]
android_namespace = sys.argv[3]
ios_bundle_id = sys.argv[4]
macos_bundle_id = sys.argv[5]
apple_team = sys.argv[6]
test_suffix = sys.argv[7]


def update(path: Path, transform):
    if not path.exists():
        print(f"skip    {path.relative_to(root)}")
        return
    original = path.read_text()
    changed = transform(original)
    if changed != original:
        path.write_text(changed)
        print(f"updated {path.relative_to(root)}")
    else:
        print(f"ok      {path.relative_to(root)}")


# Android Gradle configuration. Match the assignment itself so command-line
# overrides work even after the template identifier has already been replaced.
gradle = root / "android/app/build.gradle.kts"
def android_gradle(text: str) -> str:
    text = re.sub(
        r'(?m)^(\s*namespace\s*=\s*)"[^"]+"',
        rf'\1"{android_namespace}"',
        text,
    )
    text = re.sub(
        r'(?m)^(\s*applicationId\s*=\s*)"[^"]+"',
        rf'\1"{android_app_id}"',
        text,
    )
    return text
update(gradle, android_gradle)

# Android MainActivity package and source path.
kotlin_root = root / "android/app/src/main/kotlin"
activities = list(kotlin_root.rglob("MainActivity.kt")) if kotlin_root.exists() else []
if len(activities) > 1:
    raise SystemExit("ERROR: multiple MainActivity.kt files found; refusing to guess")
if activities:
    source = activities[0]
    text = source.read_text()
    text = re.sub(r'(?m)^package\s+[A-Za-z0-9_.]+\s*$', f'package {android_namespace}', text)
    target = kotlin_root.joinpath(*android_namespace.split("."), "MainActivity.kt")
    target.parent.mkdir(parents=True, exist_ok=True)
    if source != target:
        target.write_text(text)
        source.unlink()
        # Remove now-empty legacy package directories, stopping at kotlin/.
        parent = source.parent
        while parent != kotlin_root:
            try:
                parent.rmdir()
            except OSError:
                break
            parent = parent.parent
        print(f"moved   {source.relative_to(root)} -> {target.relative_to(root)}")
    elif text != source.read_text():
        source.write_text(text)
        print(f"updated {source.relative_to(root)}")
    else:
        print(f"ok      {source.relative_to(root)}")

# iOS app/test bundle IDs and Apple signing team.
ios_project = root / "ios/Runner.xcodeproj/project.pbxproj"
def ios_project_config(text: str) -> str:
    # RunnerTests first to avoid a generic replacement touching the test suffix.
    text = re.sub(
        r'PRODUCT_BUNDLE_IDENTIFIER = [A-Za-z0-9_.-]+\.RunnerTests;',
        f'PRODUCT_BUNDLE_IDENTIFIER = {ios_bundle_id}.{test_suffix};',
        text,
    )
    # Runner configurations are the remaining non-test explicit bundle IDs.
    text = re.sub(
        r'PRODUCT_BUNDLE_IDENTIFIER = (?![^;]*RunnerTests)[A-Za-z0-9_.-]+;',
        f'PRODUCT_BUNDLE_IDENTIFIER = {ios_bundle_id};',
        text,
    )
    text = re.sub(
        r'DEVELOPMENT_TEAM = [A-Z0-9]{10};',
        f'DEVELOPMENT_TEAM = {apple_team};',
        text,
    )
    return text
update(ios_project, ios_project_config)

# macOS app bundle ID lives in AppInfo.xcconfig.
macos_app_info = root / "macos/Runner/Configs/AppInfo.xcconfig"
def macos_app_config(text: str) -> str:
    return re.sub(
        r'(?m)^PRODUCT_BUNDLE_IDENTIFIER\s*=\s*\S+\s*$',
        f'PRODUCT_BUNDLE_IDENTIFIER = {macos_bundle_id}',
        text,
    )
update(macos_app_info, macos_app_config)

# macOS tests and any explicit signing team live in the Xcode project.
macos_project = root / "macos/Runner.xcodeproj/project.pbxproj"
def macos_project_config(text: str) -> str:
    text = re.sub(
        r'PRODUCT_BUNDLE_IDENTIFIER = [A-Za-z0-9_.-]+\.RunnerTests;',
        f'PRODUCT_BUNDLE_IDENTIFIER = {macos_bundle_id}.{test_suffix};',
        text,
    )
    text = re.sub(
        r'DEVELOPMENT_TEAM = [A-Z0-9]{10};',
        f'DEVELOPMENT_TEAM = {apple_team};',
        text,
    )
    return text
update(macos_project, macos_project_config)

print()
print(f"Android applicationId: {android_app_id}")
print(f"Android namespace    : {android_namespace}")
print(f"iOS bundle ID        : {ios_bundle_id}")
print(f"macOS bundle ID      : {macos_bundle_id}")
print(f"Apple team           : {apple_team}")
PY

printf '\nProject identifiers configured.\n'
