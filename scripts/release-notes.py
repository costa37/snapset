import json, re
from pathlib import Path
version = json.loads(Path('version.json').read_text())['version']
match = re.search(r'^## ' + re.escape(version) + r'\n(.*?)(?=^## |\Z)', Path('CHANGELOG.md').read_text(), re.M | re.S)
if not match or not match[1].strip():
    raise SystemExit('Add CHANGELOG.md notes for this version.')
notes = match[1].strip() + '''

## Install

Apple silicon, macOS 13+. Download the ZIP, unzip, and move SnapSet.app into Applications. This personal build is ad-hoc signed and not Apple-notarized. If macOS blocks it, use Open Anyway in Privacy & Security only if you trust this download. Enable Accessibility access to inspect and move windows. After an update, macOS may require removing and re-adding SnapSet in Accessibility settings.

Settings stay locally in ~/Library/Application Support/SnapSet/layout.json. Automatic checks use Sparkle; installing updates requires confirmation. Automated layout/matching tests and update signature verification passed. Live placement across physical monitors and Sparkle install/relaunch still require interactive validation.
'''
Path('dist/release-notes.txt').write_text(notes)
