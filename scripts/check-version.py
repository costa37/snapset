import json, os, subprocess
from pathlib import Path
current = json.loads(Path('version.json').read_text())
old = json.loads(subprocess.check_output(['git','show',os.environ['PREVIOUS_TAG'] + ':version.json'], text=True))
if tuple(map(int,current['version'].split('.'))) <= tuple(map(int,old['version'].split('.'))) or current['build'] <= old['build']:
    raise SystemExit('Both version and build must increase beyond the previous release.')
