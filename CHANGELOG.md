# Changelog

## 0.3.2

- Add an app-name search box shared by Open windows and Saved rules.
- Match any part of the name, ignoring case and surrounding whitespace; show only matching apps.
- Show filtered counts, a clear-search control, and an empty-result message. Searching does not modify saved rules or the scope of Apply layout.

## 0.3.1

- Left-click the menu-bar icon to open and activate SnapSet, including restoring a closed or minimized settings window.
- Right-click the icon to open its menu, keeping layout, login, update, and Quit controls available.
- Retain one settings window and preserve its position and size.

## 0.3.0

- Apply Main display + Wide centered to windows without a saved exception; no individual Save is required.
- Apply layouts on SnapSet startup and shortly after applications launch, as well as existing manual/reconnection triggers.
- Support saved Main display targets that follow changes to the macOS main display.
- Keep disabled, ambiguous, conflicting, and disconnected-display rules from being overridden by the fallback.
- Add Launch at login, requested by default and registered when running from Applications, with visible approval/error status.
- Run as a menu-bar utility without a separate Dock icon or left-side application menu; settings remain available from the menu-bar icon.

## 0.2.3

- Show the installed app version in small, secondary text beside the SnapSet heading.
- Read the version from app metadata so the label stays correct after updates.

## 0.2.2

- Add the selected Center Stage app icon: a blue tile with a white monitor and cyan centered window.
- Bundle native macOS icon sizes for Finder, Dock, and application switching.

## 0.2.1

- Add Wide centered: two-thirds of the usable display width, centered, with full usable height.
- Use Wide centered as the default for unsaved windows and new rules, preserving explicitly saved placements.
- Label connected displays Main, Extended, or Mirrored using the system display configuration.

## 0.2.0

- Rename Window Harbor to SnapSet.
- Browse currently open standard windows in a table and save a display and placement for each.
- Support separate rules for multiple windows of the same app, using document URLs, exact titles, or title fragments.
- Track selected windows through title changes during the current session; skip ambiguous matches and conflicting rules.
- Keep manual application and automatic restoration after display reconnection/wake; app-focus activation remains optional.
- Save configuration locally and migrate earlier Window Harbor settings without overwriting the original file.
- Add Sparkle update checks with separately signed GitHub release archives.
