import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--godot', type=Path, required=True)
parser.add_argument('--game-pack', type=Path, required=True)
parser.add_argument('--reference-project', type=Path, required=True)
parser.add_argument('--mod-package', type=Path, required=True)
parser.add_argument('--test-script', type=Path, default=Path('tests/modes_native_test.gd'))
parser.add_argument('--result-marker', default='MODE_TEST_RESULT failures=0')
parser.add_argument('--timeout', type=int, default=120)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
    reservation.bind(('127.0.0.1', 0))
    port = reservation.getsockname()[1]
processes = []
try:
    for host in (True, False):
        role = 'host' if host else 'client'
        project = root / 'dist' / ('native-modes-' + role)
        project.mkdir(parents=True, exist_ok=True)
        shutil.copy2(args.godot, project / 'probe.exe')
        for library in args.godot.parent.glob('*.dll'):
            shutil.copy2(library, project / library.name)
        config = args.reference_project.read_text().replace('addons/qodot/game_definitions/', 'addons/qodot/game-definitions/')
        user_dir = 'CruS Modes Test ' + role
        config = config.replace('config/name="Cruelty Squad"', 'config/name="' + user_dir + '"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + user_dir + '"')
        config = config.replace('[autoload]', '[autoload]\nBoot="*res://mode_boot.gd"')
        config = '\n'.join(line for line in config.splitlines() if not any(line.startswith(key) for key in ('boot_splash/image=', 'config/icon=', 'mouse_cursor/custom_image=', 'environment/default_environment=')))
        (project / 'project.godot').write_text(config)
        (project / 'mode_boot.gd').write_text('extends Node\nfunc _init():\n\tProjectSettings.load_resource_pack(' + json.dumps(args.game_pack.resolve().as_posix()) + ')\n\tAudioServer.set_bus_layout(load("res://default_bus_layout.tres"))\n')
        mod = Path(os.environ['APPDATA']) / user_dir / 'mods' / 'CruS Online'
        mod.mkdir(parents=True, exist_ok=True)
        probe = (root / args.test_script).read_text().replace('HOST', 'true' if host else 'false').replace('PORT', str(port))
        with zipfile.ZipFile(args.mod_package) as source, zipfile.ZipFile(mod / 'mod.zip', 'w', zipfile.ZIP_DEFLATED) as target:
            for name in source.namelist():
                data = source.read(name)
                if name.endswith('/multiplayer_init.gd'):
                    data += b'\n\tGlobal.add_child(load("res://MOD_CONTENT/CruS Online/modes_native_test.gd").new())\n'
                target.writestr(name, data)
            target.writestr('MOD_CONTENT/CruS Online/modes_native_test.gd', probe)
        shutil.copy2(args.mod_package.parent / 'mod.json', mod / 'mod.json')
        output = (project / 'output.log').open('w')
        process = subprocess.Popen([str(project / 'probe.exe'), '--path', str(project), '--no-window'], cwd=project, stdout=output, stderr=subprocess.STDOUT, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        processes.append((role, process, output, project))
    failed = False
    for role, process, output, project in processes:
        try:
            process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        output.close()
        result = (project / 'output.log').read_text()
        print(role, 'exit=', process.returncode)
        print('\n'.join(line for line in result.splitlines() if 'MODE_' in line or 'CAPTURE_' in line or 'ERROR:' in line))
        failed |= process.returncode != 0 or args.result_marker not in result or 'SCRIPT ERROR:' in result
    raise SystemExit(1 if failed else 0)
finally:
    for _, process, output, _ in processes:
        if process.poll() is None:
            process.kill()
            process.wait()
        output.close()
