#!/usr/bin/env python3
"""Fail when protected Rust application/core/platform crates depend on frontend frameworks."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "experiments" / "gpui-desktop" / "Cargo.toml"
PROTECTED_PACKAGES = {"dextryx-core", "dextryx-frontend-api", "dextryx-platform"}
FORBIDDEN_NAMES = {
    "gpui",
    "gpui_platform",
    "flutter_rust_bridge",
    "flutter_rust_bridge_codegen",
    "dextryx-gpui-spike",
    "dextryx-ffi",
}


def metadata() -> dict:
    result = subprocess.run(
        [
            "cargo",
            "metadata",
            "--format-version",
            "1",
            "--manifest-path",
            str(MANIFEST),
        ],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def main() -> int:
    data = metadata()
    packages = {package["id"]: package for package in data["packages"]}
    protected_ids = {
        package_id
        for package_id, package in packages.items()
        if package["name"] in PROTECTED_PACKAGES
    }

    missing = PROTECTED_PACKAGES - {
        packages[package_id]["name"] for package_id in protected_ids
    }
    if missing:
        print(f"missing protected Cargo packages: {sorted(missing)}", file=sys.stderr)
        return 2

    graph = {
        node["id"]: [dependency["pkg"] for dependency in node.get("deps", [])]
        for node in data.get("resolve", {}).get("nodes", [])
    }

    violations: list[tuple[str, str]] = []
    for root_id in protected_ids:
        root_name = packages[root_id]["name"]
        seen: set[str] = set()
        stack = list(graph.get(root_id, []))
        while stack:
            package_id = stack.pop()
            if package_id in seen:
                continue
            seen.add(package_id)
            package = packages.get(package_id)
            if package is None:
                continue
            dependency_name = package["name"]
            if dependency_name in FORBIDDEN_NAMES:
                violations.append((root_name, dependency_name))
            stack.extend(graph.get(package_id, []))

    if violations:
        for root_name, dependency_name in sorted(set(violations)):
            print(
                f"forbidden dependency: {root_name} transitively depends on {dependency_name}",
                file=sys.stderr,
            )
        return 1

    print("Rust core/application/platform dependency boundary: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
