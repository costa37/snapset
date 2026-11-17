# SnapSet

Put each window back where it belongs. A native Apple silicon macOS app with a table of open windows, saved display/placement rules, a menu-bar action, and automatic restoration after monitors reconnect.

**macOS 13+ · Apple silicon · Version 0.2.1**

## Install

1. Download `SnapSet-0.2.1-arm64.zip` from [Releases](https://github.com/costa37/snapset/releases).
2. Unzip and move **SnapSet.app** into Applications, then open it.
3. This personal build is ad-hoc signed and not Apple-notarized. If macOS blocks it, review System Settings → Privacy & Security and use **Open Anyway** only if you trust the download. Managed Macs may prohibit it.
4. Click **Enable access…** and enable SnapSet in Privacy & Security → Accessibility. Return to SnapSet and click **Refresh windows**. If needed, quit and reopen the app.

## Configure windows

The **Open windows** table lists standard windows exposed by running apps through macOS Accessibility, including minimized/full-screen windows marked as such. It refreshes when SnapSet becomes active or when you click Refresh windows. Dialogs, utility panels, and windows an app does not expose are not included. This is a list of windows, not individual browser tabs.

For each window, choose a **destination display**, **placement**, then **Save**. Saving does not move the window. Click **Apply layout** to apply all enabled rules. The menu-bar action works even when the settings window is closed; Command–Return applies while settings is focused.

The default for unsaved windows and new rules is **Wide centered**: two-thirds width, horizontally centered, and full usable desktop height. Existing saved placements remain as configured.

Available placements: Wide centered, almost maximized (12-point margin), maximized within the desktop, half width centered, left half, right half, and compact centered (60% width / 70% height). The Dock/menu bar are excluded. Maximizing does not enter macOS full-screen mode.

Automatic restoration after display changes or wake is enabled by default, with a two-second settling delay. Application-focus activation is optional and starts off. Missing displays are skipped. Apps must be running; minimized and full-screen windows are not moved.

## Multiple windows from one app

Each window can have its own rule and a different monitor/size. SnapSet remembers the selected live window through title changes until it closes or SnapSet quits. Across restarts, saved matching uses:

- **Document URL** when provided by the app; usually the most stable identity for an open document.
- **Exact title** otherwise. Browser titles can change with the active tab.
- **Title contains**, editable under Saved rules, for a stable project name or another unique fragment. Matching is case-insensitive.
- **All app windows**, an explicit option applying the same rectangle to every standard window of that app. These windows may overlap.

Window order and transient window numbers are not persistent identities. If a rule matches multiple windows after restart, SnapSet skips it and reports ambiguity. If multiple rules target one window, that window is skipped. Give similar windows distinct titles or more specific matching rules. A blank/untitled window can be tracked in the current session, but needs a unique persistent match for future launches.

## Local configuration

`~/Library/Application Support/SnapSet/layout.json`

Rules, application bundle IDs, document URLs/title patterns, display UUIDs, placements, and trigger preferences are saved as readable JSON using atomic writes. **Show configuration file** reveals it in Finder. The app loads it at launch; quit SnapSet before editing or restoring a backup. App updates do not replace this folder. Configuration is local to each Mac; there is no cloud sync or telemetry. It is not encrypted, and window titles/document paths can contain personal information.

If no SnapSet configuration exists, it imports the older `WindowHarbor/layout.json` without changing that file. Earlier all-window rules are preserved; old single-window rules are disabled until a specific match is configured. Invalid or newer-format configuration files are preserved and saving is blocked with a visible error.

Display choices begin with **Main**, **Extended**, or **Mirrored**, based on macOS display configuration (not which display currently has keyboard focus).

Display UUIDs survive ordinary reconnections, but some dock/adapter changes can change the identity reported by macOS. Re-select the display in that case. The app may constrain its own size or reject window control; results appear below the table. Spaces and Stage Manager can affect window availability. SnapSet does not switch Spaces.

## Updates

Like G-Clip, SnapSet uses Sparkle 2.10.1 with GitHub Releases. Automatic checks are on by default and can be disabled; **Check for Updates…** is also available in settings and the menu bar. Installation requires confirmation. Each ZIP is Ed25519-signed with SnapSet's own key; Sparkle verifies it before extraction. System profiling and automatic installation are disabled.

Update checks/downloads contact GitHub and its asset hosting service. Window titles, document paths, and layout settings are not sent. Ad-hoc signing means macOS may require removing and re-adding SnapSet in Accessibility after an update, even when the toggle still looks enabled.

## Build and test

Install Apple's command-line developer tools, then:

```sh
bash scripts/test.sh
bash scripts/build.sh
```

The build downloads the pinned Sparkle dependency using Swift Package Manager and produces `dist/SnapSet.app`. There is no Apple Developer account requirement. `CONFIGURATION=debug bash scripts/build.sh` enables a debug build. Tests use the command-line Swift compiler and do not require XCTest or full Xcode.

See [RELEASE.md](RELEASE.md) for signing and publishing. GitHub Actions builds/tests source; signing happens locally with the private key kept in Keychain.

## Validation status

Automated checks cover multi-monitor coordinate conversion, preset bounds, saved-rule serialization, unique/ambiguous matching, session bindings, overlapping rules, and legacy migration. Feed metadata and update signatures are also checked. Actual window placement across monitors and Sparkle installation/relaunch require interactive testing after granting Accessibility; they are not claimed as validated by a build alone.

MIT license. Sparkle's license is bundled inside the application.
