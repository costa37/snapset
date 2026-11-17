#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/snapset-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
swiftc -Onone -module-cache-path "$PWD/.build/module-cache" Sources/SnapSet/Layout.swift Sources/SnapSet/Rules.swift Sources/SnapSet/WindowManager.swift Tests/LayoutTests.swift -o "$test_dir/layout-tests"
"$test_dir/layout-tests"
python3 scripts/test-appcast.py
