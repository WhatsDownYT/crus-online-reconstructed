# Project layout

For how these pieces work together, see the [codebase guide](codebase_guide.md).

- `core/` starts the mod and manages save and profile data
- `network/` contains sessions, transport, lobbies, replication, and player peers
- `gameplay/` contains rules, implants, interactions, and mission behavior
- `interface/` contains menus, HUD elements, and their scenes
- `voice/` contains voice capture, encoding, and effects
- `weapons/` contains the custom weapon API; install weapon packages under `user://weapons/`, as described in [its guide](../weapons/README.md)
- `achievements/` contains goal definitions, portraits, and presentation
- `assets/` contains interface and implant images and audio
- `branding/`, `campaigns/`, `compatibility/`, `effects/`, `entities/`, `maps/`, `models/`, and `player_model/` hold their named game content
- `remapped/` contains overrides of original game resources; original filenames are intentionally preserved
- `examples/` contains optional missions, campaigns, and editable weapon packages. Mission folder names follow CruS Mod Base's name lookup convention
- `development/tools/` contains build, export, and diagnostic scripts; `development/tests/` contains test scripts; generated outputs and captures go in ignored `development/artifacts/`
- `docs/` contains reference material, and `full_changelog.txt` records public changes

Builds exclude `development/`, `docs/`, and `examples/`. Add runtime content to the appropriate shipped folder, then update resource paths when moving it. Check the archive with `development/tools/audit_resource_paths.py` and `development/tools/check_game_resources.py`.
