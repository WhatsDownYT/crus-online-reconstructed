




import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
import re
import socket
import time
import wave

parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
parser.add_argument('--lan', action='store_true', help='Also run three real ENet processes on loopback')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='crus-network-test-') as directory:
    project = Path(directory)
    source_engine = Path(args.godot).resolve()
    test_engine = project / source_engine.name
    shutil.copy2(source_engine, test_engine)
    for library in source_engine.parent.glob('*.dll'):
        shutil.copy2(library, project / library.name)
    mod = project / 'MOD_CONTENT' / 'CruS Online'
    mod.mkdir(parents=True)
    for name in ('SteamNetwork.gd', 'NetworkMetrics.gd', 'NetworkSnapshots.gd', 'NetworkBridge.gd', 'FriendlyFire.gd', 'EnemyTargeting.gd', 'ImplantNetwork.gd', 'PlayerCollisionProxy.gd', 'SessionFlow.gd', 'DiscordPresence.gd', 'VoiceChat.gd', 'VoiceCodec.gd', 'VoiceRoster.gd', 'VoiceSettings.gd', 'DifficultyLabel.gd', 'PlayerActionPolicy.gd', 'PropInteractionPolicy.gd', 'MissionExitPolicy.gd', 'ProfileStore.gd', 'FloatingPanel.gd', 'SpiritualDoorPolicy.gd', 'CancerSegment.gd'):
        shutil.copy2(root / name, mod / name)


    integration = ('VoiceChat.gd', 'multiplayer.gd', 'multiplayer_player.gd', 'SteamLobby.gd', 'multiplayer_menu.gd', 'Players.gd', 'Menu.gd', 'Stats.gd', 'ChatBox.gd',
                   'CancerSegment.gd', 'CancerReplication.gd', 'entities/Enemy_Torso.gd', 'remaped/Kinematic_Physics_Object.gd',
                   'remaped/Switch.gd', 'remaped/Door.gd', 'remaped/down_door.gd', 'remaped/down_switch_door.gd', 'remaped/Divine_Door.gd', 'remaped/Profane_Door.gd', 'remaped/Terror_Door.gd', 'remaped/Elevator.gd', 'remaped/weapon.gd',
                   'remaped/Player.gd', 'remaped/Exit.gd', 'remaped/Game_Manager.gd', 'entities/EnemyHandler.gd',
                   'remaped/Player_Manager.gd', 'entities/E_Grunt_Movement_New.gd', 'entities/material_randomizer.gd', 'entities/Enemy_Melee_Weapon.gd')
    for name in integration:
        destination = mod / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / name, destination)
        for resource in re.findall(r'preload\("(res://[^\"]+\.tscn)"\)', destination.read_text(encoding='utf-8')):
            asset = project / resource.removeprefix('res://')
            asset.parent.mkdir(parents=True, exist_ok=True)
            asset.write_text('[gd_scene format=2]\n[node name="Stub" type="Spatial"]\n', encoding='utf-8')
            if asset.name == 'Alert_Sphere_Big.tscn':
                asset.write_text('[gd_scene format=2]\n[node name="Alert" type="Area"]\n'
                                 '[node name="CollisionShape" type="CollisionShape" parent="."]\n', encoding='utf-8')
        for resource in re.findall(r'preload\("(res://[^\"]+\.tres)"\)', destination.read_text(encoding='utf-8')):
            asset = project / resource.removeprefix('res://')
            asset.parent.mkdir(parents=True, exist_ok=True)
            asset.write_text('[gd_resource type="SpatialMaterial" format=2]\n[resource]\n', encoding='utf-8')
        for resource in re.findall(r'preload\("(res://[^\"]+\.(?:png|ogg|wav))"\)', destination.read_text(encoding='utf-8')):
            asset = project / resource.removeprefix('res://')
            asset.parent.mkdir(parents=True, exist_ok=True)
            kind = 'ImageTexture' if asset.suffix == '.png' else 'AudioStreamSample'
            sample = asset.with_name(asset.name + '.tres')
            sample.write_text(f'[gd_resource type="{kind}" format=2]\n[resource]\n', encoding='utf-8')
            asset.touch()
            asset.with_name(asset.name + '.import').write_text('[remap]\n'
                f'type="{kind}"\npath="res://' + sample.relative_to(project).as_posix() + '"\n', encoding='utf-8')
    for name in ('Elevator_Bell.wav', 'Elevator_Move.wav'):
        asset = project / 'Sfx' / 'Environment' / name
        asset.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(asset), 'wb') as audio:
            audio.setparams((1, 2, 22050, 1, 'NONE', 'not compressed'))
            audio.writeframes(b'\0\0')
        sample = asset.with_suffix('.tres')
        sample.write_text('[gd_resource type="AudioStreamSample" format=2]\n'
                          '[resource]\nformat = 1\nmix_rate = 22050\ndata = PoolByteArray( 0, 0 )\n', encoding='utf-8')
        asset.with_name(asset.name + '.import').write_text('[remap]\nimporter="wav"\n'
            'type="AudioStreamSample"\npath="res://' + sample.relative_to(project).as_posix() + '"\n', encoding='utf-8')
    (project / 'project.godot').write_text(
        'config_version=4\n[application]\nconfig/name="CruS Transport Tests"\nrun/main_scene="res://test.tscn"\n'
        '[autoload]\nGlobal="*res://global.gd"\n'
        '[rendering]\nquality/driver/driver_name="GLES2"\n', encoding='utf-8')
    (project / 'global.gd').write_text('extends Node\nvar player\nvar UI\nvar objectives = 0\nvar objective_complete = false\n'
                                     'var soul_intact = true\nvar husk_mode = false\nvar hope_discarded = false\n'
                                     'var death = false\nvar implants\nvar CURRENT_LEVEL = 0\nvar DEAD_CIVS = []\n'
                                     'var last_scene = \"\"\nfunc goto_scene(path):\n\tlast_scene = path\nvar menu\nvar LEVEL_AMBIENCE = [null]\nvar ambience\nvar music\n', encoding='utf-8')
    menu_source = (root / 'menu.tscn').read_text(encoding='utf-8')
    for match in re.finditer(r'script/source = "((?:[^"\\]|\\.)*)"', menu_source):
        source = match.group(1).replace(r'\"', '"').replace('\\\\', '\\')
        for collection in ('playerNameImage', 'playerSkins'):
            if f'var {collection}' in source:
                (project / f'{collection}.gd').write_text(source, encoding='utf-8')
    shutil.copy2(root / 'tests/transport_test.gd', project / 'test.gd')
    shutil.copy2(root / 'tests/voice_test.gd', project / 'voice_test.gd')
    (project / 'test.tscn').write_text('[gd_scene load_steps=2 format=2]\n'
        '[ext_resource path="res://test.gd" type="Script" id=1]\n'
        '[node name="Tests" type="Node"]\nscript = ExtResource( 1 )\n', encoding='utf-8')
    result = subprocess.run([str(test_engine), '--no-window', '--path', str(project),
                             '--quit'],
                            capture_output=True, text=True, timeout=45)
    output = result.stdout + result.stderr
    print(output)
    print('Engine exit:', result.returncode)
    if result.returncode or 'TRANSPORT_TEST_RESULT failures=0' not in output or 'ERROR:' in output:
        raise SystemExit(1)
    if args.lan:
        shutil.copy2(root / 'tests/lan_test.gd', project / 'lan_test.gd')
        (project / 'lan.tscn').write_text('[gd_scene load_steps=2 format=2]\n'
            '[ext_resource path="res://lan_test.gd" type="Script" id=1]\n'
            '[node name="Tests" type="Node"]\nscript = ExtResource( 1 )\n', encoding='utf-8')
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
            reservation.bind(('127.0.0.1', 0))
            port = reservation.getsockname()[1]
        processes = []
        try:
            for role in ('host', 'client_a', 'client_b'):
                processes.append(subprocess.Popen(
                    [str(test_engine), '--no-window', '--path', str(project), 'res://lan.tscn',
                     f'--role={role}', f'--port={port}'], stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT, text=True,
                    creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0)))
                if role == 'host':
                    time.sleep(0.5)
            for process in processes:
                output, _ = process.communicate(timeout=20)
                print(output)
                if process.returncode or 'LAN_TEST_RESULT' not in output or 'ERROR:' in output:
                    raise SystemExit(1)
        finally:
            for process in processes:
                if process.poll() is None:
                    process.kill()
                    process.wait()
