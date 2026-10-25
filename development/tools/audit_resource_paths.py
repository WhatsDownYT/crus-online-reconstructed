"""Report static mod-local resource references missing from a built archive."""

import argparse
from pathlib import Path
import re
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('package', type=Path)
args = parser.parse_args()
prefix = 'MOD_CONTENT/CruS Online/'
with zipfile.ZipFile(args.package) as archive:
    names = set(archive.namelist())
    missing = {}
    for name in names:
        if not name.startswith(prefix) or not name.endswith(('.gd', '.tscn', '.tres', '.json', '.import')):
            continue
        data = archive.read(name).decode('utf-8', errors='ignore')
        for target in re.findall(r'res://(MOD_CONTENT/CruS Online/[^"\s]+)', data):
            target = target.rstrip('\\')
            if not Path(target).suffix:
                continue
            if target not in names and '${' not in target and '%' not in target:
                missing.setdefault(target, []).append(name)
for target, sources in sorted(missing.items()):
    print(f'{target} <- {sources[0]}')
print(f'MISSING_RESOURCE_PATHS={len(missing)}')
raise SystemExit(bool(missing))
