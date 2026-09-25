import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess


parser = argparse.ArgumentParser()
parser.add_argument('--godot', type=Path, required=True)
parser.add_argument('--game-pack', type=Path, required=True)
parser.add_argument('--scene', type=Path)
parser.add_argument('--level-images-source', type=Path)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()

if bool(args.scene) == bool(args.level_images_source):
    parser.error('Choose exactly one of --scene and --level-images-source')
if args.scene:
    source = args.scene.read_text(encoding='utf-8')
    textures = {int(index): path for path, index in re.findall(
        r'^\[ext_resource path="res://([^"]+)" type="Texture" id=(\d+)\]', source, re.MULTILINE)}
    used = {int(index) for group in re.findall(r'^images = \[(.*?)\]', source, re.MULTILINE)
            for index in re.findall(r'ExtResource\( (\d+) \)', group)}
    paths = sorted({textures[index] for index in used})
else:
    source = args.level_images_source.read_text(encoding='utf-8')
    match = re.search(r'var LEVEL_IMAGES = \[(.*?)\]', source, re.DOTALL)
    if not match:
        raise SystemExit('LEVEL_IMAGES list not found')
    paths = re.findall(r'preload\("res://([^"]+)"\)', match.group(1))
project = Path(__file__).resolve().parents[1] / 'dist' / 'ending-image-export-project'
project.mkdir(parents=True, exist_ok=True)
output = args.output.resolve()
for path in paths:
    (output / Path(path).parent).mkdir(parents=True, exist_ok=True)
(project / 'project.godot').write_text(
    'config_version=4\n[application]\nconfig/name="Ending Image Export"\n'
    'run/main_scene="res://export.tscn"\n[rendering]\nquality/driver/driver_name="GLES3"\n', encoding='utf-8')
(project / 'export.tscn').write_text(
    '[gd_scene load_steps=2 format=2]\n'
    '[ext_resource path="res://export.gd" type="Script" id=1]\n'
    '[node name="Export" type="Node"]\nscript = ExtResource( 1 )\n', encoding='utf-8')
gdscript = '''extends Node
func _ready():
    if not ProjectSettings.load_resource_pack(GAME_PACK):
        printerr("PACK_FAIL")
        get_tree().quit(1)
        return
    var failures = 0
    for path in PATHS:
        var texture = load("res://" + path)
        if texture == null:
            printerr("IMAGE_FAIL load ", path)
            failures += 1
            continue
        var image = texture.get_data()
        if image == null:
            printerr("IMAGE_FAIL data ", path)
            failures += 1
            continue
        if image.is_compressed() and image.decompress() != OK:
            printerr("IMAGE_FAIL decompress ", path)
            failures += 1
            continue
        var target = OUTPUT + "/" + path
        if image.save_png(target) != OK:
            printerr("IMAGE_FAIL save ", path)
            failures += 1
        else:
            print("IMAGE_OK ", path, " ", image.get_width(), "x", image.get_height())
    print("IMAGE_RESULT failures=", failures)
    get_tree().quit(1 if failures else 0)
'''.replace('GAME_PACK', json.dumps(args.game_pack.resolve().as_posix())).replace(
    'PATHS', json.dumps(paths)).replace('OUTPUT', json.dumps(output.as_posix()))
(project / 'export.gd').write_text(gdscript, encoding='utf-8')
engine = project / 'export.exe'
shutil.copy2(args.godot, engine)
for library in args.godot.parent.glob('*.dll'):
    shutil.copy2(library, project / library.name)
result = subprocess.run([str(engine), '--no-window', '--path', str(project)],
                        cwd=project, capture_output=True, text=True, timeout=120,
                        creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
print(result.stdout)
print(result.stderr)
print(f'EXPECTED={len(paths)} EXPORTED={len(list(output.rglob("*.png")))}')
if result.returncode or 'IMAGE_RESULT failures=0' not in result.stdout:
    raise SystemExit(1)
