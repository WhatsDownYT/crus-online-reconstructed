import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import time
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--extensions', type=Path, default=Path(r'E:\Cruelty\Extensions'))
parser.add_argument('--godot', type=Path, required=True)
parser.add_argument('--game-pack', type=Path, required=True)
parser.add_argument('--reference-project', type=Path, required=True)
parser.add_argument('--mod-package', type=Path, required=True)
parser.add_argument('--real-restart', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
profiles = {role: Path(os.environ['APPDATA']) / ('CruS Extensions Test ' + role) for role in ('host', 'client')}
for profile in profiles.values():
    if profile.exists():
        if profile.name not in ('CruS Extensions Test host', 'CruS Extensions Test client'):
            raise SystemExit('Unexpected test profile')
        shutil.rmtree(profile)
    profile.mkdir(parents=True)
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
    reservation.bind(('127.0.0.1', 0))
    port = reservation.getsockname()[1]
fixture = root / 'dist/extensions-loader.zip'
with zipfile.ZipFile(fixture, 'w', zipfile.ZIP_DEFLATED) as archive:
    archive.writestr('modloader.gd.remap', '[remap]\npath="res://extensions-loader.gd"\n')
    archive.writestr('extensions-loader.gd', (args.extensions / 'Loader/modloader.gd').read_bytes())
base = profiles['host'] / 'mods/CruS Mod Base'
base.mkdir(parents=True)
source = args.extensions / 'Modbase'
with zipfile.ZipFile(base / 'mod.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in source.rglob('*'):
        relative = path.relative_to(source)
        if not path.is_file() or any(part in ('.git', 'logs') for part in relative.parts) or relative.as_posix() in ('project.godot', 'mod.json', 'build.ps1', 'build.zsh') or path.suffix in ('.gdc', '.bak') or path.name.endswith('.gd.remap'):
            continue
        archive.write(path, relative.as_posix())
shutil.copy2(source / 'mod.json', base / 'mod.json')
with zipfile.ZipFile(args.extensions / 'hiltonhitjob.zip') as archive:
    for name in archive.namelist():
        destination = profiles['host'] / 'levels' / name
        if name.endswith('/'):
            destination.mkdir(parents=True, exist_ok=True)
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(archive.read(name))
(profiles['host'] / 'custom_level_times.save').write_text(json.dumps({
    'Hilton Hitjob_raw_time': 83,
    'Hilton Hitjob_string_time': '1:23',
    'Hilton Hitjob_punished': True,
}))

def prepare(role, stage):
    project = root / 'dist' / ('extensions-' + role)
    project.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.godot, project / 'probe.exe')
    for library in args.godot.parent.glob('*.dll'):
        shutil.copy2(library, project / library.name)
    config = args.reference_project.read_text().replace('addons/qodot/game_definitions/', 'addons/qodot/game-definitions/')
    user_dir = 'CruS Extensions Test ' + role
    config = config.replace('config/name="Cruelty Squad"', 'config/name="' + user_dir + '"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + user_dir + '"')
    config = config.replace('[autoload]', '[autoload]\nBoot="*res://extensions_boot.gd"')
    config = '\n'.join(line for line in config.splitlines() if not any(line.startswith(key) for key in ('boot_splash/image=', 'config/icon=', 'mouse_cursor/custom_image=', 'environment/default_environment=')))
    (project / 'project.godot').write_text(config)
    (project / 'extensions_boot.gd').write_text('extends Node\nfunc _init():\n\tProjectSettings.load_resource_pack(' + json.dumps(args.game_pack.resolve().as_posix()) + ')\n\tProjectSettings.load_resource_pack(' + json.dumps(fixture.as_posix()) + ')\n\tAudioServer.set_bus_layout(load("res://default_bus_layout.tres"))\n')
    probe = (root / 'tests/extensions_native_test.gd').read_text().replace('ROLE', json.dumps(stage)).replace('PORT', str(port)).replace('READY_PATH', json.dumps((profiles['host'] / 'client-ready').as_posix()))
    mod = profiles[role] / 'mods/CruS Online'
    mod.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.mod_package) as source, zipfile.ZipFile(mod / 'mod.zip', 'w', zipfile.ZIP_DEFLATED) as target:
        for name in source.namelist():
            data = source.read(name)
            if name.endswith('.gd'):
                data = data.replace(b'\r\n', b'\n').replace(b'\r', b'\n')
            if name.endswith('/multiplayer_init.gd'):
                data = data.replace(b'func _init():', b'func _init():\n\tGlobal.call_deferred("add_child", load("res://MOD_CONTENT/CruS Online/extensions_native_test.gd").new())', 1)
            if name.endswith('/LobbyContent.gd') and not args.real_restart:
                start = data.index(b'func restart_game():')
                end = data.index(b'func resume_join():', start)
                data = data[:start] + b'func restart_game():\n\tprint("EXTENSION_RESTART_READY")\n\tget_tree().quit()\n\n' + data[end:]
            target.writestr(name, data)
        target.writestr('MOD_CONTENT/CruS Online/extensions_native_test.gd', probe)
    shutil.copy2(args.mod_package.parent / 'mod.json', mod / 'mod.json')
    return project

processes = []
def launch(role, stage):
    project = prepare(role, stage)
    log_path = project / (stage + '.log')
    output = log_path.open('w')
    process = subprocess.Popen([str(project / 'probe.exe'), '--path', str(project), '--no-window'], cwd=project, stdout=output, stderr=subprocess.STDOUT, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    processes.append((stage, process, output, log_path))
    return process, log_path

try:
    host, host_log = launch('host', 'host')
    client, client_log = launch('client', 'download')
    client.wait(timeout=170)
    for stage, _, output, _ in processes:
        if stage == 'download':
            output.close()
    if client.returncode != 0 or (not args.real_restart and 'EXTENSION_RESTART_READY' not in client_log.read_text()):
        raise RuntimeError('Content download/install failed')
    if args.real_restart:
        deadline = time.monotonic() + 140
        result = profiles['client'] / 'extension-result'
        while not result.exists() and time.monotonic() < deadline:
            time.sleep(0.5)
        if not result.exists() or result.read_text() != '0':
            raise RuntimeError('Actual executable restart/rejoin failed')
        print('ACTUAL_RESTART_RESULT failures=0')
        log = profiles['client'] / 'logs/godot.log'
        if log.exists() and 'SCRIPT ERROR:' in log.read_text():
            raise RuntimeError('Restarted client reported script errors')
    else:
        client, client_log = launch('client', 'rejoin')
        client.wait(timeout=140)
    host.wait(timeout=140)
    failed = False
    for stage, process, output, log in processes:
        output.close()
        text = log.read_text()
        print(stage, 'exit=', process.returncode)
        print('\n'.join(line for line in text.splitlines() if line.startswith(('EXTENSION_', 'SCRIPT ERROR:', 'ERROR:', '[CruS content]'))))
        failed |= process.returncode != 0 or 'SCRIPT ERROR:' in text or (stage != 'download' and 'failures=0' not in text)
    raise SystemExit(1 if failed else 0)
finally:
    for stage, process, output, log in processes:
        if process.poll() is None:
            process.kill()
            process.wait()
        output.close()
        if process.returncode != 0:
            print(stage, '\n', '\n'.join(log.read_text().splitlines()[-25:]))
