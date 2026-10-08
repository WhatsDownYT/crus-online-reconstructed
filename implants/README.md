# Custom implants

CruS Online exposes `ImplantRegistry` at `Global.get_node("ImplantRegistry")`.
Definitions use `ImplantDefinition.gd`. Put a definition, icon, and optional
behavior script in one folder, then either add the definition path to
`implants/catalog.json` or register it from a dependent mod:

```gdscript
var registry = Global.get_node("ImplantRegistry")
registry.register_implant(preload("res://MOD_CONTENT/Your Mod/implants/my_implant.tres"))
```

`implants/examples/PracticeReflex.tres` is a discoverable example paired with
the `Implant Test Range` custom mission. It is in `catalog.json`, but registers
only while that mission is installed. Copy the folder and replace its
placeholder icon, ID, name, description, price, slot, behavior, pickup scene,
point class, and source mission before registering your own implant.

Use a stable namespaced `implant_id` such as `your_mod:my_implant`. Purchases
save that ID, so the display name can change without breaking ownership.
`slot` is Head, Torso, Arms, or Legs. If `discoverable` is `true`, the Custom
page shows a mystery icon until the player finds the pickup in a mission. The
pickup grants ownership without a purchase. A discoverable implant must have a
`point_class` resource; its `classname` is the entity to place in a TrenchBroom
map. The example uses `Practice_Reflex_Implant`. Its pickup scene
sets the Area node's `implant_name` to the stable ID
`example:practice_reflex`. Multiple copies can be placed in any map; previously
collected copies disappear when that save slot loads the mission again.
Set `source_level` to the source mission's folder and displayed name. Its
`level.json` must list the implant ID in `required_implants`, and its scene
must use the pickup point class. The registry rejects a discoverable implant
when that mission or reciprocal declaration is absent. Mod Base rejects a
mission declaring an implant that is unavailable or that does not name that
mission as its source. The test mission also declares its required custom
weapon in `required_weapons`.

If `discoverable` is `false`, the implant is visible in the Custom page from
the start and can be purchased normally. Neither setting grants it for free at
startup. Custom pages expand as needed, and normal equip, tooltip, and host-ban
rules apply. Register the definition before building a Qodot map so its point
class is available to the level editor.

`modifiers` maps existing implant properties to values. The registry validates
the supported names and types before registration. For example,
`{"speed_bonus": 1.0, "jump_bonus": 2.0}` uses the game's normal movement
calculations. Properties such as `armor`, `ammo_bonus`, `camo`, `nightvision`,
and `multiplayer_stealth` can be used in the same way. See the allowlists in
`ImplantRegistry.gd` for all supported properties.

An optional `behavior` is a `Reference` script with any of these methods:

```gdscript
func on_equip(player, implant):
    pass
func on_unequip(player, implant):
    pass
func on_process(player, implant, delta):
    pass
func on_use(player, implant):
    pass
```

Hooks run for the local living player in a mission. `on_use` runs when the
definition's `input_action` is pressed; that action must exist in Godot's
InputMap. The registry adds equipped custom IDs to the multiplayer implant
state as `custom_implants`. Existing synchronized modifier flags work through
the usual implant sync. A new scripted effect that changes the world or other
players must send and validate its own network action through the mod's
networking layer. Players in the same lobby need the same implant definition
and behavior files.
