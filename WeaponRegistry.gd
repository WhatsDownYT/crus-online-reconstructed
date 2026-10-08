extends Node

signal catalog_changed

const VANILLA_COUNT = 29
var pending = {}
var registration_order = []
var definitions = {}
var indices = {}
var names = {}

func load_bundled_weapons():
	var manifest = File.new()
	if manifest.open("res://MOD_CONTENT/CruS Online/weapons/catalog.json", File.READ) != OK:
		push_error("Could not open the CruS Online weapon catalog")
		return
	var catalog = parse_json(manifest.get_as_text())
	manifest.close()
	if not catalog is Array:
		push_error("Invalid CruS Online weapon catalog")
		return
	var fgd = load("res://addons/qodot/game-definitions/fgd/qodot_fgd.tres")
	for entry in catalog:
		if not entry is Dictionary or not entry.has("definition"):
			continue
		var definition = load(entry.definition)
		if definition == null or not register_weapon(definition):
			continue
		if fgd == null:
			continue
		for point_path in entry.get("point_classes", []):
			var point_class = load(point_path)
			if point_class == null:
				continue
			var exists = false
			for entity in fgd.entity_definitions:
				if entity.get("classname") == point_class.classname:
					exists = true
					break
			if not exists:
				fgd.entity_definitions.append(point_class)

func register_weapon(definition):
	if not definition is Resource or not definition.get("weapon_id") is String:
		push_error("Invalid weapon definition")
		return false
	var key = definition.weapon_id.strip_edges().to_lower()
	if key.empty() or key.find(":") < 1 or pending.has(key):
		push_error("Duplicate or invalid weapon ID: " + key)
		return false
	if definition.magazine_size < 1 or definition.maximum_total_rounds < definition.magazine_size or definition.starting_reserve < 0 or definition.magazine_size + definition.starting_reserve > definition.maximum_total_rounds:
		push_error("Invalid ammunition values for " + key)
		return false
	pending[key] = definition
	registration_order.append(key)
	call_deferred("finalize")
	return true

func finalize():
	var changed = false
	for key in registration_order:
		if indices.has(key):
			continue
		var index = VANILLA_COUNT + indices.size()
		indices[key] = index
		definitions[index] = pending[key]
		names[index] = key
		changed = true
	if changed:
		_extend_global_save_arrays()
		emit_signal("catalog_changed")

func _extend_global_save_arrays():
	while Global.WEAPONS_UNLOCKED.size() < VANILLA_COUNT + indices.size():
		var next_index = Global.WEAPONS_UNLOCKED.size()
		Global.WEAPONS_UNLOCKED.append(bool(definitions[next_index].unlocked_by_default))
	while Global.CURRENT_WEAPONS.size() < VANILLA_COUNT + indices.size():
		Global.CURRENT_WEAPONS.append(false)

func index_for(key:String)->int:
	return indices.get(key.to_lower(), -1)

func has_weapon(key:String)->bool:
	return pending.has(key.to_lower())

func definition_for(index:int):
	return definitions.get(index, null)

func id_for(index:int)->String:
	return names.get(index, "")

func is_custom(index)->bool:
	return typeof(index) == TYPE_INT and definitions.has(index)
