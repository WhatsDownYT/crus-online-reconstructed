# CruS Online weapons

Weapons in this folder are part of CruS Online. `tools/build_mod.py` packages
them into the main `CruS Online/mod.zip`. `catalog.json` lists the weapon
definitions and their Qodot map entities. `WeaponRegistry.gd` reads it during
startup, adds each weapon after the 29 vanilla weapons, and tells the weapon
menu which entries to show.

To create another weapon using this prototype:

1. Copy `herschel_f2500` to a new folder and rename its files and resource
   paths. Give the definition resource a unique namespaced `weapon_id`, such
   as `your_name:weapon_name`. Use `F2500.tres` as the example for its displayed
   name, descriptions, rifle ammunition, damage, weight, unlock state,
   `behavior` script, icon, world/view/remote models and fire sounds. Saved
   custom unlocks use this ID
2. Write a behavior script extending `Reference`. Its `fire_primary(gun)`
   handles normal fire. Its optional `fire_secondary(gun)` handles the
   **Shoot Secondary** action, which defaults to middle mouse and can be
   rebound in Settings. The weapon script calls these methods on the equipped
   behavior instead of adding another vanilla weapon ID case
3. If the weapon fires a projectile, keep its scene and script in the same
   folder. The F2500 behavior shows how to create and replicate one; its
   grenade script handles collision, explosion and shrapnel
4. Put the weapon's mesh, texture, menu icon and sounds inside
   its own `assets` directory. The F2500 copies Godot-imported game resources
   as initial stand-ins; replace them with your own imported resources for
   original art and audio. `F2500World.tscn` is used for pickups and menu
   previews, `F2500Remote.tscn` for other players, and `F2500View.tscn` supplies
   mesh and material to the animated first-person weapon node. The common
   first-person arms, animation player, muzzle-flash effect and explosion
   behavior still belong to the base game. Keep a `MeshInstance` root on each
   model scene. A remote model puts its muzzle flash first, primary sound
   second and secondary sound third so multiplayer playback can address them
5. Append its definition path to `catalog.json`. For map placement, make an
   inherited pickup scene and a Qodot point-class resource like the F2500
   examples, then list the point class in the same catalog entry
6. Build CruS Online normally with `tools/build_mod.py`, then test the weapon
   in a mission and with another player

The F2500 specifies its animation names and first-person view slot directly;
it does not use `borrowed_model_index`. Its model, texture, icon and sounds are
local resources, including its grenade mesh. It uses the game's common bullet
decal and animation rig, which are shared weapon-system effects. The example
pickup and SWAT scenes currently
specify runtime weapon slot 29; the next catalog weapon will
use slot 30, so its map scenes must use 30. Keep catalog entries in the same
order, and ensure every player in a multiplayer lobby has the same catalog.
This is the present limit of the
prototype, not a finished third-party weapon packaging format.

`herschel_f2500` demonstrates the layout. Its primary attack is an automatic
15-damage rifle with 30 loaded and 135 spare rounds, capped at 200 total
rounds from pickups. Shoot Secondary fires its launcher: one grenade
is loaded, three are spare, and the loaded chamber is refilled from reserve
after two seconds. Collecting another F2500 replenishes one launcher grenade,
up to six held at once. The impact grenade uses a piercing explosion and 32
damaging shrapnel rays. The blast and shrapnel can hurt the shooter. The Load
Bearing Vest changes starting reserves to 180 rifle rounds and four grenades.

`Herschel_F2500` and `Herschel_F2500_SWAT` are Qodot point
entities for a pickup and a Cult of Order SWAT enemy armed with the launcher.
