import argparse
import json
from pathlib import Path
import re
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--base-package', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
prefix = 'MOD_CONTENT/CruS Online/'
excluded = {'.git', 'dist', 'docs', 'tests', 'tools', '__pycache__'}
runtime_suffixes = {'.gd', '.tscn', '.tres', '.res', '.png', '.jpg', '.jpeg', '.webp', '.svg',
                    '.import', '.glb', '.gltf', '.obj', '.mtl', '.material', '.wav', '.ogg', '.ttf', '.shader'}
if args.base_package.resolve() == (args.output / 'mod.zip').resolve():
    raise SystemExit('Choose an output folder separate from the installed mod.')
with zipfile.ZipFile(args.base_package) as base:
    entries = {name: base.read(name) for name in base.namelist()
               if not name.endswith('/') and not name.startswith(prefix)}
    entries.pop('Menu/Main_Menu.tscn.remap', None)
    entries['Switch.gd.remap'] = b'[remap]\npath="res://MOD_CONTENT/CruS Online/remaped/Switch.gd"\n'
    for source, target in [('Scripts/Night_Cycle.gd', 'Night_Cycle.gd'), ('Menu/Level_End_Grid.gd', 'Level_End_Grid.gd')]:
        entries[source + '.remap'] = ('[remap]\npath="res://' + prefix + 'remaped/' + target + '"\n').encode()
    for path in root.rglob('*'):
        relative = path.relative_to(root)
        if not path.is_file() or any(part in excluded for part in relative.parts):
            continue
        if path.suffix.lower() in runtime_suffixes:
            entries[prefix + relative.as_posix()] = path.read_bytes()
    for name, data in entries.items():
        if name.endswith('.remap'):
            for target in re.findall(r'path="res://([^"]+)"', data.decode('utf-8-sig')):
                if target.startswith(prefix) and target not in entries:
                    raise SystemExit(f'Missing remap target: {name} -> {target}')
    for path in root.rglob('*.import'):
        relative = path.relative_to(root)
        if any(part in excluded for part in relative.parts):
            continue
        archive_name = prefix + relative.as_posix()
        original_name = archive_name.removesuffix('.import')
        if original_name in base.namelist() and original_name in entries:
            if base.read(original_name) != entries[original_name]:
                raise SystemExit(f'Asset changed and needs reimporting: {original_name}')
        if archive_name in base.namelist():
            entries[archive_name] = base.read(archive_name)
        for imported in re.findall(r'^path(?:\.s3tc)?="res://(\.import/[^"]+)"', entries[archive_name].decode('utf-8'), re.MULTILINE):
            if imported not in entries:
                raise SystemExit(f'Missing imported asset: {archive_name} -> {imported}')
args.output.mkdir(parents=True, exist_ok=True)
temporary = args.output / 'mod.zip.tmp'
with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED) as output:
    for name, data in sorted(entries.items()):
        output.writestr(name, data)
with zipfile.ZipFile(temporary) as output:
    if output.testzip() is not None:
        raise SystemExit('Archive verification failed.')
    for name, data in entries.items():
        if output.read(name) != data:
            raise SystemExit(f'Archive content mismatch: {name}')
temporary.replace(args.output / 'mod.zip')
version = re.search(r'var version = "([^"]+)"', (root / 'multiplayer.gd').read_text()).group(1)
metadata = {'author': 'TriggeredP', 'description': 'multiplayer',
            'init': 'res://' + prefix + 'multiplayer_init.gd', 'name': 'CruS Online', 'version': version}
(args.output / 'mod.json').write_text(json.dumps(metadata), encoding='utf-8')
print(f'BUILD_RESULT files={len(entries)} output={args.output.resolve()}')
