"""Copy the F2500 example's starting assets from the installed game's PCK.

The copied resources are Godot's compiled mesh, texture and audio resources.
They are kept in the weapon directory so the example has no runtime art/audio
dependency on the corresponding vanilla AR or rocket launcher files.
"""

from pathlib import Path
import struct
import sys


ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "weapons/herschel_f2500/assets"
ASSETS = {
    "res://.import/AR.obj-1f7349b7d213674ac7b3d15aff8f4456.mesh": "rifle.mesh",
    "res://.import/AR.png-6ab36f553848da634e3e71f3612a9fc7.s3tc.stex": "rifle_texture.stex",
    "res://.import/AR.png-bf9d7f0ab68bd7433e80a9e4d5684b4f.stex": "rifle_icon.stex",
    "res://.import/AR_fire.wav-2dbb4a8465150b884bad032393e965a9.sample": "rifle_fire.sample",
    "res://.import/rocketlauncher_fire.wav-f3ca759542fa64040ce09d1d5c4fb61f.sample": "launcher_fire.sample",
    "res://.import/Gas_Grenade.obj-8dc1e5e69decfae6077064d077bf9f7c.mesh": "grenade.mesh",
}


def main(pck_path: Path) -> None:
    with pck_path.open("rb") as package:
        if package.read(4) != b"GDPC":
            raise SystemExit("Not a Godot PCK")
        package.seek(0x54)
        count = struct.unpack("<I", package.read(4))[0]
        found = {}
        for _ in range(count):
            length = struct.unpack("<I", package.read(4))[0]
            name = package.read(length).decode("utf-8").rstrip("\x00")
            offset, size = struct.unpack("<QQ", package.read(16))
            package.read(16)  # MD5
            if name in ASSETS:
                found[name] = (offset, size)
        missing = set(ASSETS) - set(found)
        if missing:
            raise SystemExit("Missing resources: " + ", ".join(sorted(missing)))
        DESTINATION.mkdir(parents=True, exist_ok=True)
        for source, filename in ASSETS.items():
            offset, size = found[source]
            package.seek(offset)
            (DESTINATION / filename).write_bytes(package.read(size))
            print(filename, size)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
