# Changelog

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
