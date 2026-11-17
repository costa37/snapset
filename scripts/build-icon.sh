#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
icon_dir="$(mktemp -d "${TMPDIR:-/tmp}/snapset-icon.XXXXXX")"
trap 'rm -rf "$icon_dir"' EXIT
mkdir "$icon_dir/SnapSet.iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Assets/SnapSet.png --out "$icon_dir/SnapSet.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Assets/SnapSet.png --out "$icon_dir/SnapSet.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$icon_dir/SnapSet.iconset" -o Assets/SnapSet.icns
