import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--godot', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]

with tempfile.TemporaryDirectory(prefix='crus-snapshot-test-') as directory:
    project = Path(directory)
    engine = project / args.godot.name
    shutil.copy2(args.godot, engine)
    for library in args.godot.parent.glob('*.dll'):
        shutil.copy2(library, project / library.name)
    shutil.copy2(root / 'network/network_snapshots.gd', project / 'network_snapshots.gd')
    shutil.copy2(root / 'development/tests/snapshot_arity_native_test.gd', project / 'test.gd')
    (project / 'project.godot').write_text(
        'config_version=4\n[application]\nconfig/name="CruS Snapshot Test"\n'
        'run/main_scene="res://test.tscn"\n[rendering]\nquality/driver/driver_name="GLES2"\n',
        encoding='utf-8',
    )
    (project / 'test.tscn').write_text(
        '[gd_scene load_steps=2 format=2]\n'
        '[ext_resource path="res://test.gd" type="Script" id=1]\n'
        '[node name="Test" type="Node"]\nscript = ExtResource( 1 )\n',
        encoding='utf-8',
    )
    result = subprocess.run(
        [str(engine), '--no-window', '--path', str(project), '--quit'],
        capture_output=True, text=True, timeout=20,
    )
    output = result.stdout + result.stderr
    print(output)
    if result.returncode or 'SNAPSHOT_ARITY_RESULT valid=True missing_hold=False invalid_hold=False' not in output or 'ERROR:' in output:
        raise SystemExit(1)
