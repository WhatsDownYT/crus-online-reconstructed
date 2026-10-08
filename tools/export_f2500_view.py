"""Save the vanilla AR view mesh as the F2500 example's local starter mesh."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess


parser = argparse.ArgumentParser()
parser.add_argument("--godot", type=Path, required=True)
parser.add_argument("--game-pack", type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
project = root / "dist/f2500-view-export"
project.mkdir(parents=True, exist_ok=True)
output = root / "weapons/herschel_f2500/assets/rifle_view.res"
(project / "project.godot").write_text('config_version=4\n[application]\nconfig/name="F2500 View Export"\nrun/main_scene="res://export.tscn"\n')
(project / "export.tscn").write_text('[gd_scene load_steps=2 format=2]\n[ext_resource path="res://export.gd" type="Script" id=1]\n[node name="Export" type="Node"]\nscript = ExtResource( 1 )\n')
script = '''extends Node
func _ready():
    if not ProjectSettings.load_resource_pack(GAME_PACK):
        get_tree().quit(1)
        return
    var scene = load("res://Imported_Mesh/Player_Weapon_New.glb")
    if scene == null:
        print("F2500_VIEW_FAIL scene")
        get_tree().quit(1)
        return
    var rig = scene.instance()
    var ar = rig.find_node("AR", true, false)
    if not ar is MeshInstance or ar.mesh == null:
        print("F2500_VIEW_FAIL node")
        get_tree().quit(1)
        return
    print("F2500_VIEW_AABB ", ar.mesh.get_aabb())
    var world_mesh = load("res://Imported_Mesh/Weapon_Mesh_Only/AR.obj")
    if world_mesh != null:
        print("F2500_WORLD_AABB ", world_mesh.get_aabb())
    var mesh = ar.mesh.duplicate(true)
    for surface in range(mesh.get_surface_count()):
        mesh.surface_set_material(surface, null)
    var error = ResourceSaver.save(OUTPUT, mesh)
    print("F2500_VIEW_RESULT error=", error)
    rig.free()
    get_tree().quit(1 if error != OK else 0)
'''.replace("GAME_PACK", json.dumps(args.game_pack.resolve().as_posix())).replace("OUTPUT", json.dumps(output.as_posix()))
(project / "export.gd").write_text(script)
shutil.copy2(args.godot, project / "export.exe")
for library in args.godot.parent.glob("*.dll"):
    shutil.copy2(library, project / library.name)
result = subprocess.run([str(project / "export.exe"), "--no-window", "--path", str(project)], cwd=project,
                        capture_output=True, text=True, timeout=120)
print(result.stdout)
print(result.stderr)
if result.returncode or "F2500_VIEW_RESULT error=0" not in result.stdout:
    raise SystemExit(1)
