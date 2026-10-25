"""Package one editable custom weapon folder for user://weapons/<folder>/weapon.zip."""

import argparse
import json
from pathlib import Path
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
source = args.source.resolve()
manifest = json.loads((source / 'weapon.json').read_text(encoding='utf-8'))
required = [manifest['definition'], *manifest.get('point_classes', [])]
for name in required:
    if not (source / name).is_file():
        raise SystemExit(f'Missing weapon resource: {name}')
args.output.parent.mkdir(parents=True, exist_ok=True)
prefix = f'CUSTOM_WEAPONS/{source.name}/'
with zipfile.ZipFile(args.output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(source.rglob('*')):
        if path.is_file() and path.suffix.lower() in {'.json', '.gd', '.tscn', '.tres', '.res', '.mesh', '.sample', '.stex', '.png', '.import', '.wav', '.ogg', '.shader'}:
            archive.write(path, prefix + path.relative_to(source).as_posix())
with zipfile.ZipFile(args.output) as archive:
    if archive.testzip() is not None:
        raise SystemExit('Weapon archive verification failed')
print(f'WEAPON_BUILD files={len(archive.namelist())} output={args.output.resolve()}')
