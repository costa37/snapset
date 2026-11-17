#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="dist/SnapSet.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
codesign --verify --deep --strict "$APP"
ARCHIVE="SnapSet-$VERSION-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/$ARCHIVE"
(cd dist && shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256")
python3 scripts/create-appcast.py
