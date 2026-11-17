#!/bin/bash
# Same release model as G-Clip: build/sign on the release Mac, publish only verified artifacts.
set -euo pipefail
cd "$(dirname "$0")/.."
unset GH_TOKEN GITHUB_TOKEN
export GH_CONFIG_DIR="$HOME/.config/gh-costa37"
REPO=costa37/snapset
[ "$(gh api user --jq .login)" = costa37 ] || { echo 'Use the dedicated costa37 profile.' >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo 'Commit source changes before releasing.' >&2; exit 1; }
[ "$(git rev-parse HEAD)" = "$(gh api "repos/$REPO/commits/main" --jq .sha)" ] || { echo 'Push this commit to main before releasing.' >&2; exit 1; }
VERSION=$(python3 -c 'import json; print(json.load(open("version.json"))["version"])')
TAG="v$VERSION"
if gh release view "$TAG" --repo "$REPO" > /dev/null 2>&1; then
    echo "Release $TAG already exists; inspect it before retrying." >&2; exit 1
fi
# Refuse versions that would leave current Sparkle clients unable to upgrade.
previous=$(gh release list --repo "$REPO" --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName // ""')
if [ -n "$previous" ]; then
    git fetch origin "refs/tags/$previous:refs/tags/$previous"
    PREVIOUS_TAG="$previous" python3 scripts/check-version.py
fi
bash scripts/test.sh
bash scripts/build.sh
bash scripts/package.sh
(cd dist && shasum -a 256 -c "SnapSet-$VERSION-arm64.zip.sha256")
python3 scripts/release-notes.py
gh release create "$TAG" --repo "$REPO" --target "$(git rev-parse HEAD)" --title "SnapSet $VERSION" --notes-file dist/release-notes.txt --draft
gh release upload "$TAG" --repo "$REPO" "dist/SnapSet-$VERSION-arm64.zip" "dist/SnapSet-$VERSION-arm64.zip.sha256" dist/appcast.xml
gh release edit "$TAG" --repo "$REPO" --draft=false --latest
gh release view "$TAG" --repo "$REPO" --json url --jq .url
