import html
import json
from pathlib import Path
import shutil
import subprocess
import wave

root = Path(__file__).resolve().parents[1]
output = root / 'docs' / 'eyecam-sound-candidates'
project = root / 'dist' / 'eyecam-sound-export'
output.mkdir(parents=True, exist_ok=True)
project.mkdir(parents=True, exist_ok=True)
paths = [
    'Sfx/UI/UI_navigation.wav', 'Sfx/UI/UI_navigation_2.wav',
    'Sfx/UI/UI_selection.wav', 'Sfx/UI/Implant_Equip.wav',
    'Sfx/UI/implant_unequip.wav', 'Sfx/UI/Target.wav', 'Sfx/UI/Target-old1.wav',
    'Sfx/Environment/sinebeep.wav', 'Sfx/Environment/Elevator_Bell.wav',
    'Sfx/WeaponsPickups/pickup_health.wav', 'Sfx/fishcatch.wav', 'Sfx/slots.wav',
    'Sfx/Player/IED_armed_1.wav', 'Sfx/Player/IED_armed_2.wav',
    'Sfx/Sniper/targetacquired.wav', 'Sfx/Sniper/canthide.wav', 'Sfx/superchimp.wav',
    'Sfx/UI/Slosh.wav', 'Sfx/UI/UI_grunt.wav',
]
manifest = [{'file': f'{i:02d}_{Path(path).stem}.wav', 'source': path} for i, path in enumerate(paths, 1)]
(output / 'sources.json').write_text(json.dumps(manifest, indent=2))
(project / 'project.godot').write_text('config_version=4\n[application]\nconfig/name="Eyecam Sound Export"\nrun/main_scene="res://export.tscn"\n[rendering]\nquality/driver/driver_name="GLES3"\n')
(project / 'export.tscn').write_text('[gd_scene load_steps=2 format=2]\n[ext_resource path="res://export.gd" type="Script" id=1]\n[node name="Export" type="Node"]\nscript = ExtResource( 1 )\n')
script = """extends Node
func _ready():
    if not ProjectSettings.load_resource_pack(PACK):
        get_tree().quit(1)
        return
    var failures = 0
    for item in ITEMS:
        var sound = load("res://" + item.source)
        if sound == null or not sound is AudioStreamSample or sound.save_to_wav(OUTPUT + "/" + item.file) != OK:
            print("SOUND_FAIL ", item.source)
            failures += 1
        else:
            print("SOUND_OK ", item.file)
    print("SOUND_RESULT failures=", failures)
    get_tree().quit(1 if failures else 0)
""".replace('PACK', json.dumps('E:/# Steam/steamapps/common/Cruelty Squad/crueltysquad.pck')).replace('ITEMS', json.dumps(manifest)).replace('OUTPUT', json.dumps(output.as_posix()))
(project / 'export.gd').write_text(script)
game = Path('E:/# Steam/steamapps/common/Cruelty Squad')
engine = project / 'export.exe'
shutil.copy2(game / 'crueltysquad.exe', engine)
for library in game.glob('*.dll'):
    shutil.copy2(library, project / library.name)
result = subprocess.run([str(engine), '--no-window', '--path', str(project)], cwd=project, capture_output=True, text=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
print(result.stdout)
print(result.stderr)
if result.returncode or 'SOUND_RESULT failures=0' not in result.stdout:
    raise SystemExit(1)
rows=[]
for item in manifest:
    with wave.open(str(output / item['file'])) as audio:
        item['seconds'] = round(audio.getnframes() / audio.getframerate(), 3)
    rows.append('<article><h2>' + html.escape(item['file']) + '</h2><p>' + html.escape(item['source']) + ' ? ' + str(item['seconds']) + ' seconds</p><audio controls preload="none" src="' + html.escape(item['file']) + '"></audio></article>')
(output / 'sources.json').write_text(json.dumps(manifest, indent=2))
(output / 'Listen.html').write_text('<!doctype html><meta charset="utf-8"><title>Eyecam sound candidates</title><style>body{font:16px system-ui;background:#171717;color:#eee;max-width:900px;margin:32px auto;padding:0 20px}h2{font-size:18px}article{padding:12px 0;border-top:1px solid #444}p{color:#aaa}audio{width:100%}</style><h1>Eyecam sound candidates</h1><p>Original game sounds, without pitch or timing changes. Pick one for first scans and one for loading a saved scan. Start with the UI sounds and sinebeep; the spoken lines and superchimp are additional alternatives.</p>' + ''.join(rows) + '<script>for(const audio of document.querySelectorAll("audio")){audio.volume=0.35;audio.addEventListener("play",()=>{for(const other of document.querySelectorAll("audio")){if(other!==audio)other.pause();}});}</script>', encoding='utf-8')
print(f'EXPORTED={len(manifest)} OUTPUT={output}')
