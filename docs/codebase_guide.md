# CruS Revitalized codebase guide

This guide is a starting point for reading or changing CruS Revitalized. [Project layout](project_layout.md) lists the folders; this page explains how the main systems meet. Scripts under `remapped/` replace original Cruelty Squad resources, so changes there need to preserve the game's expected node paths, signals, and serialized data.

## Startup and session flow

1. Modloader mounts the Online archive and starts `core/multiplayer_init.gd`. It creates the weapon registry, loads installed weapon packages, and adds the Online session, menu, death screen, and goal managers
2. `network/multiplayer.gd` owns the session roster and host settings. Its children split transport (`network/network_bridge.gd`, `network/steam_network.gd`, `network/steam_lobby.gd`), mission transitions (`network/session_flow.gd`), mode rules (`gameplay/deathmatch.gd`, `gameplay/counter_op.gd`), and optional systems such as voice
3. The host selects a mission and sends world and loading state. `SessionFlow` waits for participants, applies shared mission settings, and directs results. Clients render and interact with that state; they do not decide the result themselves
4. Returning to menus clears mission state while the lobby can remain active. Offline missions take the normal singleplayer path

`remapped/Game_Manager.gd` holds save and global game integration. `remapped/Menu_Test.gd` and `interface/` build the menus around the original scene. The similarly named `interface/Menu.gd` is the Online panel inside that scene, not the game's global menu manager.

## Network authority

Start with `network/network_bridge.gd` when an interaction must cross the network. It registers RPC permissions and resolves who caused damage. Gameplay policies under `gameplay/` decide whether a particular action is legal; they should be applied before an accepted request changes the host simulation. Effects spawned from another effect must retain their original attacker's identity for team rules and kill credit.

Use an ordinary RPC for an event that must happen once, such as a pickup, death, or match result. `network/network_snapshots.gd` is for replaceable visual state such as transforms: updates to the same member are coalesced and sent within a packet budget. `network/network_metrics.gd` records transport behavior without changing the simulation.

Voice is separate from gameplay packets. `voice/voice_chat.gd` handles capture, routing, and playback; `voice/voice_codec.gd` handles packet audio; `voice/voice_effects.gd` applies implant and environmental processing. Hearing rules and spatial playback change between lobby, mission, death, and results.

## Saves and goals

Save slot 1 uses the game's existing save path. Additional slots use their own paths through `remapped/Game_Manager.gd`. `core/profile_store.gd` writes Online profile data through a temporary file and preserves a valid backup. `interface/save_slot_selector.gd` reads a slot for preview without making it the active save.

`achievements/achievement_goals.gd` evaluates and records goals for the active slot. `achievements/achievement_preview.gd` queues the small phone notifications, while `achievements/goals_screen.gd` builds the browsable Goals menu. UI animations never determine whether a goal was earned.

## Adding content

For a custom weapon, read [Custom weapons](../weapons/README.md). The API remains in `weapons/`, while each installed package lives at `user://weapons/<folder>/weapon.zip`. `weapon.json` points to a Godot definition and optional Qodot point classes. A stable `weapon_id` identifies the weapon in saves and map scenes; `WeaponRegistry` assigns its runtime array index after the vanilla weapons. All players in an Online session need matching packages because some original replication still uses those indices.

Online implant extensions are built into this mod. Their game behavior is in `remapped/Implants.gd` and relevant `gameplay/` scripts, with supporting images in `assets/implants/`. New behavior that affects other players needs an authority and synchronization path; a new menu icon alone does not make an implant multiplayer-ready.

Custom missions and campaigns are managed by CruS Mod Base. `gameplay/extension_compatibility.gd` connects them to Online menus and level selection. Optional examples live under `examples/` and are excluded from the Online archive. `network/lobby_content.gd` validates and stages the mod, level, and campaign content exchanged during a join.

## Working on the project

- Keep original game override filenames where a remap depends on them; use `snake_case` for new resources under our control
- Add comments when ownership, coordinate space, save compatibility, or a network rule would be surprising to a reader. Describe the constraint or reason instead of restating each line
- Put diagnostics and temporary output under `development/`; it is excluded from the mod package
- Update `full_changelog.txt` for completed user-facing changes, grouped by feature and describing the resulting behavior
- Build with `development/tools/build_mod.py`, then run `development/tools/audit_resource_paths.py` and `development/tools/check_game_resources.py` when resource paths change. Native Godot tests are under `development/tests/`
