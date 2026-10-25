# Custom weapons

CruS Online loads weapon packages from `user://weapons/<folder>/weapon.zip`,
alongside the game's `levels` and `campaigns` folders. Each archive contains
`CUSTOM_WEAPONS/<folder>/weapon.json` and the weapon's definition, models,
textures, sounds, optional projectile, behavior, and map entities. Folder
names are sorted before registration. The editable F2500 example is in
`examples/weapons/herschel_f2500/`; its files are not part of the Online mod.

## Make an ordinary gun

1. Copy `examples/weapons/herschel_f2500/` to a new folder and replace its assets. You need a
   menu icon, a world model for pickups/previews, a first-person view model,
   a remote model for other players, and a fire sound. A remote model may have
   children named `Muzzleflash` and `FireSound`; their order does not matter.
2. Create a Godot resource using `weapons/weapon_definition.gd`, or edit the copied
   `.tres`. Give it a unique namespaced `weapon_id` such as
   `your_name:your_gun`. Set the display text, magazine and reserve sizes,
   damage, accuracy, reload time, fire intervals, icon, models, sound, and
   animation names. `armor_piercing` affects the default hitscan attack when
   the target supports piercing damage. Leave `behavior` empty for a normal
   hitscan gun: `weapons/weapon_actions.gd` supplies firing, damage, decals, ammo use,
   audiovisual feedback, and multiplayer playback.
3. Add `weapon.json` beside the definition. It names the definition resource
   and any optional Qodot point-class resources:

   ```json
   {
     "definition": "my_gun.tres",
     "point_classes": ["my_gun_pickup_point_class.tres"]
   }
   ```

   Paths here are relative to the weapon folder. Resource paths inside the
   Godot scenes and resources use `res://CUSTOM_WEAPONS/<folder>/...`.
4. To place a pickup or give the gun to an enemy, make an inherited scene like
   `f2500_pickup.tscn` or `f2500_swat.tscn`. Add a `weapons/weapon_id_binder.gd` child to
   its weapon node and set `weapon_id` to the definition's ID. The binder
   resolves the runtime slot before the weapon initializes, so the scene does
   not contain a numbered weapon index. Put the scene in a Qodot point-class
   resource and name that resource in `weapon.json`.
5. Build the weapon archive with
   `python development/tools/build_weapon.py examples/weapons/<folder> development/artifacts/<folder>/weapon.zip`.
   Copy `weapon.zip` to the game's `user://weapons/<folder>/` directory. Restart
   the game, try the gun in a mission, and test it with a second player. Every
   player must have the same weapon packages and definitions.

## Secondary attacks and unusual weapons

For a projectile secondary attack, set `launcher_magazine_size`, its reserve
and maximum values, `launcher_reload_time`, `secondary_projectile`, and
`secondary_projectile_speed` on the definition. The default `weapons/weapon_actions.gd`
uses Shoot Secondary, tracks ammunition separately for each equipped custom
weapon, and asks the host to spawn the projectile. Its scene script controls
movement, collision, explosions, and other effects. The F2500 grenade is an
example. The host accepts only a projectile scene named by a registered
weapon, and checks the requesting player's equipped weapon, position, speed,
and fire interval.

For mechanics beyond the defaults, write a `Reference` script extending
`weapons/weapon_actions.gd` and override `fire_primary(gun)` or
`fire_secondary(gun)`. Set it as the definition's `behavior`. You can call the
inherited methods when only part of an attack is different. Custom world
changes still need a synchronized, host-validated implementation; the
projectile helper covers the common projectile case, not every possible
weapon effect. The F2500's behavior script is deliberately just an extension
of the shared defaults.

The built-in weapon system still uses runtime slots internally. Stable IDs
are used for saving, map placement, and custom projectile selection, while
other weapon replication uses slots. Registration order therefore has to be
identical on every peer. Installed weapon folders are sorted automatically;
all lobby members must have matching content.
