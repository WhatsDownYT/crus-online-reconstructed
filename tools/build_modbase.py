import argparse
import json
from pathlib import Path
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
metadata = json.loads((args.source / 'mod.json').read_text(encoding='utf-8-sig'))
if metadata.get('name') != 'CruS Mod Base':
    raise SystemExit('The source must be CruS Mod Base.')
args.output.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(args.output / 'mod.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(args.source.rglob('*')):
        relative = path.relative_to(args.source)
        if not path.is_file() or any(part in ('.git', 'logs') for part in relative.parts):
            continue
        if relative.as_posix() in ('project.godot', 'mod.json', 'build.ps1', 'build.zsh', 'README.md') or path.suffix in ('.gdc', '.bak') or path.name.endswith('.gd.remap'):
            continue
        archive.write(path, relative.as_posix())
(args.output / 'mod.json').write_text(json.dumps(metadata), encoding='utf-8')
with zipfile.ZipFile(args.output / 'mod.zip') as archive:
    if archive.testzip() is not None:
        raise SystemExit('Modbase archive verification failed.')
print('MODBASE_BUILD_RESULT output=' + str(args.output.resolve()))
