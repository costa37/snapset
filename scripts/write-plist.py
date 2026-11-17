from pathlib import Path
import json, plistlib, base64, re
root = Path(__file__).resolve().parent.parent
version = json.loads((root / 'version.json').read_text())
assert re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', version['version'])
assert type(version['build']) is int and version['build'] > 0
key = (root / 'updates/public-key.txt').read_text().strip()
assert len(base64.b64decode(key, validate=True)) == 32
info = dict(CFBundleIdentifier='local.snapset.app', CFBundleName='SnapSet', CFBundleDisplayName='SnapSet',
    CFBundleExecutable='SnapSet', CFBundleIconFile='SnapSet', CFBundlePackageType='APPL', CFBundleShortVersionString=version['version'],
    CFBundleVersion=str(version['build']), LSMinimumSystemVersion='13.0', NSHighResolutionCapable=True,
    SUFeedURL='https://github.com/costa37/snapset/releases/latest/download/appcast.xml', SUPublicEDKey=key,
    SUAllowsAutomaticUpdates=False, SUEnableAutomaticChecks=True, SUEnableSystemProfiling=False,
    SUVerifyUpdateBeforeExtraction=True)
(root / 'dist/SnapSet.app/Contents/Info.plist').write_bytes(plistlib.dumps(info))
