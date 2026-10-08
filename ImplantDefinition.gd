extends Resource
class_name OnlineImplantDefinition

# Use a namespaced ID. Purchases save this ID rather than the display name.
export(String) var implant_id = ""
export(String) var display_name = ""
export(String, MULTILINE) var description = ""
export(int) var price = 0
export(String, "Head", "Torso", "Arms", "Legs") var slot = "Head"
export(Texture) var icon
export(bool) var discoverable = false
export(Resource) var point_class
export(String) var source_level = ""

# Existing game implant properties, e.g. {"speed_bonus": 1.0}.
export(Dictionary) var modifiers = {}

# Optional Reference script with on_equip(player, implant),
# on_unequip(player, implant), on_process(player, implant, delta), and
# on_use(player, implant) methods. on_use requires input_action.
export(Script) var behavior
export(String) var input_action = ""
