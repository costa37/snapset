# Publishing SnapSet

This follows G-Clip's local-signing/GitHub Releases model. The repository is `costa37/snapset`. GitHub Actions validates source and builds the app, but does not receive the private update-signing key or publish releases.

## Signing identity

- App bundle ID and Sparkle Keychain account: `local.snapset.app`.
- Public key: `updates/public-key.txt`, embedded in every build.
- Feed: `https://github.com/costa37/snapset/releases/latest/download/appcast.xml`.
- Private key: the release Mac's login Keychain, created once with Sparkle's `generate_keys --account local.snapset.app`. Never put it in the repository or release assets. Do not rotate the committed public key after shipping without a planned migration.

Back up the signing key securely using Sparkle's documented export/import workflow. A different release Mac needs the same key. Losing it can require manual reinstallation because these builds are not Developer ID signed. A fresh clone can build with the public key but cannot sign updates without the corresponding private key.

## Personal GitHub account

Use `GH_CONFIG_DIR="$HOME/.config/gh-costa37"`, unset `GH_TOKEN` and `GITHUB_TOKEN`, and verify `gh api user --jq .login` returns `costa37`. This preserves the user's default work account. Use repository-scoped Git credentials; do not change global Git configuration.

## Release

1. Increase both `version` and `build` in `version.json`; add matching notes to `CHANGELOG.md` and update the README download filename.
2. Run tests, commit, and push to main.
3. Run `bash scripts/release.sh` from this Mac.

The script verifies account and pushed commit, refuses an existing release or non-increasing version/build, runs tests/build, creates the ZIP and checksum, signs it with Keychain, verifies against the embedded public key, and uploads assets to a draft before publishing as latest. It never silently overwrites a published release. If uploading fails, inspect the draft and resume using the exact verified files.

Every latest release must contain the ZIP, `.sha256`, and `appcast.xml`. The single-item feed targets Apple silicon/macOS 13+; reconsider feed history before raising the minimum supported OS.

## Interactive acceptance

- Grant Accessibility and inspect windows from at least two apps, including two windows from the same app.
- Place those two windows on different monitors, change a title, and reapply in the same session.
- Restart SnapSet and verify document/title matching. Confirm duplicate titles are skipped unless the match is disambiguated.
- Move the external display above and left of the Mac, reconnect it, and check centered/half/maximized presets.
- Verify minimized/full-screen windows are untouched and app size constraints are reported.
- Test Sparkle with two increasing builds and a staging feed on a second Mac or test account: check, download, install, relaunch, preservation of `layout.json`, and Accessibility permission recovery. A successful signature check alone is not this end-to-end test.
