import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import shutil

parser = argparse.ArgumentParser()
parser.add_argument('--godot', type=Path, required=True)
parser.add_argument('--game-pack', type=Path, required=True)
parser.add_argument('--mod-package', type=Path, required=True)
parser.add_argument('--reference-project', type=Path, required=True)
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix='crus-real-assets-') as directory:
    project = Path(directory)
    engine = project / 'resource-check.exe'
    shutil.copy2(args.godot, engine)
    for library in args.godot.parent.glob('*.dll'):
        shutil.copy2(library, project / library.name)
    reference = args.reference_project.read_text(encoding='utf-8')
    class_settings = reference[reference.index('_global_script_classes='):reference.index('[application]')]
    class_settings = class_settings.replace('addons/qodot/game_definitions/', 'addons/qodot/game-definitions/')
    (project / 'project.godot').write_text(
        'config_version=4\n' + class_settings + '[application]\nconfig/name="CruS Resource Check"\n'
        'config/use_custom_user_dir=true\nconfig/custom_user_dir_name="CruS Resource Check"\n'
        'run/main_scene="res://resource_check.tscn"\n[autoload]\n'
        'Global="*res://check_global.gd"\nMod="*res://check_global.gd"\nConsole="*res://check_global.gd"\n'
        '[rendering]\nquality/driver/driver_name="GLES3"\n', encoding='utf-8')
    (project / 'check_global.gd').write_text('extends Node\n', encoding='utf-8')
    (project / 'resource_check.tscn').write_text(
        '[gd_scene load_steps=2 format=2]\n[ext_resource path="res://resource_check.gd" type="Script" id=1]\n'
        '[node name="Check" type="Node"]\nscript = ExtResource( 1 )\n', encoding='utf-8')
    script = '''extends Node
func _ready():
	var failures = 0
	if not ProjectSettings.load_resource_pack(GAME_PACK):
		printerr("Could not open game pack")
		get_tree().quit(1)
		return
	if not ProjectSettings.load_resource_pack(MOD_PACKAGE):
		printerr("Could not open mod package")
		get_tree().quit(1)
		return
	for path in ["res://MOD_CONTENT/CruS Online/multiplayer.tscn",
		"res://MOD_CONTENT/CruS Online/multiplayer_player.tscn",
		"res://MOD_CONTENT/CruS Online/menu.tscn",
		"res://MOD_CONTENT/CruS Online/death_screen.tscn",
		"res://MOD_CONTENT/CruS Online/maps/crus_online_lobby.tscn",
		"res://MOD_CONTENT/CruS Online/maps_stuff/respawn_point.tscn",
		"res://Player_Manager.gd", "res://Scripts/E_Grunt_Movement_New.gd",
		"res://Scripts/material_randomizer.gd", "res://Scripts/Enemy_Melee_Weapon.gd",
		"res://Scripts/Grenade.gd", "res://Scripts/weapon.gd", "res://Scripts/new_vehicle.gd",
		"res://Explosion.gd", "res://MissileKinematic.gd", "res://Fire.gd",
		"res://Entities/Bullets/Fire_Child.gd", "res://Radiation.gd",
		"res://Cancerball.tscn", "res://Entities/Physics_Objects/Chest_Gib.tscn",
		"res://Scripts/Player.gd", "res://Scripts/Enemy_Torso.gd",
		"res://Scripts/Divine_Door.gd", "res://Scripts/Profane_Door.gd",
		"res://Terror_Door.gd", "res://Scripts/Elevator.gd", "res://Entities/soulll.gd", "res://Levels/sky_rotator.gd", "res://MOD_CONTENT/CruS Online/menu.tscn"]:
		var resource = load(path)
		if resource == null:
			failures += 1
			printerr("RESOURCE_FAIL ", path)
		else:
			print("RESOURCE_OK ", path)
			if resource is GDScript:
				var mapping = ConfigFile.new()
				var target = ""
				if mapping.load(path + ".remap") == OK:
					target = mapping.get_value("remap", "path", "")
				var source = File.new()
				if not target.begins_with("res://MOD_CONTENT/CruS Online/") or source.open(target, File.READ) != OK:
					failures += 1
					printerr("REMAP_FAIL ", path)
				elif resource.get_source_code().replace("\\r", "") != source.get_as_text().replace("\\r", ""):
					failures += 1
					printerr("STALE_SCRIPT ", path)
				source.close()
	for path in EXTRA_SCRIPTS:
		var script = load(path)
		if script == null or not script.can_instance():
			failures += 1
			printerr("SCRIPT_FAIL ", path)
	print("RESOURCE_TEST_RESULT failures=", failures)
	get_tree().quit(1 if failures else 0)
'''.replace('GAME_PACK', json.dumps(args.game_pack.resolve().as_posix())).replace(
        'MOD_PACKAGE', json.dumps(args.mod_package.resolve().as_posix()))
    root = Path(__file__).resolve().parents[1]
    extra_scripts = ['res://MOD_CONTENT/CruS Online/' + path.relative_to(root).as_posix()
                     for folder in ('remaped', 'entities') for path in sorted((root / folder).glob('*.gd'))]
    extra_scripts.extend('res://MOD_CONTENT/CruS Online/' + name for name in ('ImplantSettings.gd', 'ModeSettings.gd', 'DebugCapture.gd'))
    script = script.replace('EXTRA_SCRIPTS', json.dumps(extra_scripts))
    (project / 'resource_check.gd').write_text(script, encoding='utf-8')
    result = subprocess.run([str(engine), '--no-window', '--path', str(project)],
                            capture_output=True, text=True, timeout=90,
                            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    output = result.stdout + result.stderr
    print(output)
    if result.returncode or 'RESOURCE_TEST_RESULT failures=0' not in output or 'ERROR:' in output:
        raise SystemExit(1)
