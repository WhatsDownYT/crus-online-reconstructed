extends Node

export(String) var weapon_id = ""

func _ready():
	var registry = Global.get_node_or_null("WeaponRegistry")
	if registry == null:
		push_error("Weapon registry is unavailable for " + weapon_id)
		return
	var index = registry.resolve_scene_weapon(weapon_id)
	if index >= 0:
		get_parent().set("current_weapon", index)
