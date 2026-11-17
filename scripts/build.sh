#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
SPARKLE="$PWD/.build/artifacts/sparkle/Sparkle"
if [ ! -d "$SPARKLE/Sparkle.xcframework" ]; then
    swift package --disable-sandbox resolve
fi
FRAMEWORK="$SPARKLE/Sparkle.xcframework/macos-arm64_x86_64"
APP="$PWD/dist/SnapSet.app"
# Rebuild only our generated app directory.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
ditto "$FRAMEWORK/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$SPARKLE/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE.txt"
cp Assets/SnapSet.icns "$APP/Contents/Resources/SnapSet.icns"
flags=(-O)
if [ "${CONFIGURATION:-release}" = debug ]; then flags=(-Onone -g); fi
swiftc "${flags[@]}" -parse-as-library -target arm64-apple-macos13.0 -module-cache-path "$CLANG_MODULE_CACHE_PATH" \
    -F "$FRAMEWORK" -framework Sparkle -Xlinker -rpath -Xlinker '@executable_path/../Frameworks' \
    Sources/SnapSet/*.swift -o "$APP/Contents/MacOS/SnapSet"
python3 scripts/write-plist.py
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
