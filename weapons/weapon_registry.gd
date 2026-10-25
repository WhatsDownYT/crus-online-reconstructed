extends Node

signal catalog_changed

const VANILLA_COUNT = 29
var pending = {}
var registration_order = []
var definitions = {}
var indices = {}
var names = {}

func load_installed_weapons():
	var root = "user://weapons"
	var directory = Directory.new()
	directory.make_dir_recursive(root)
	if directory.open(root) != OK:
		push_error("Could not open the custom weapons folder")
		return
	var folders = []
	directory.list_dir_begin(true, true)
	var folder = directory.get_next()
	while not folder.empty():
		if directory.current_is_dir():
			folders.append(folder)
		folder = directory.get_next()
	directory.list_dir_end()
	folders.sort()
	for name in folders:
		var package = root + "/" + name + "/weapon.zip"
		if not File.new().file_exists(package):
			continue
		if not ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(package), false):
			push_error("Could not mount custom weapon package: " + package)
			continue
		var path = "res://CUSTOM_WEAPONS/" + name
		var manifest = File.new()
		if manifest.open(path + "/weapon.json", File.READ) != OK:
			push_error("Weapon package has no manifest: " + package)
			continue
		var entry = parse_json(manifest.get_as_text())
		manifest.close()
		if not entry is Dictionary or not entry.has("definition"):
			push_error("Invalid weapon manifest: " + path)
			continue
		var definition = load(_folder_resource(path, str(entry.definition)))
		if definition != null:
			var point_classes = []
			for point_path in entry.get("point_classes", []):
				point_classes.append(_folder_resource(path, str(point_path)))
			register_weapon(definition, point_classes)

func _folder_resource(folder:String, value:String)->String:
	return value if value.begins_with("res://") else folder + "/" + value

func register_weapon(definition, point_classes = []):
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
	if definition.primary_fire_interval <= 0 or definition.enemy_fire_interval <= 0 or definition.launcher_reload_time <= 0 or definition.secondary_projectile_speed <= 0:
		push_error("Invalid firing timings for " + key)
		return false
	if definition.launcher_magazine_size < 0 or definition.launcher_starting_reserve < 0 or definition.launcher_vest_reserve < 0 or definition.launcher_maximum_total < definition.launcher_magazine_size + max(definition.launcher_starting_reserve, definition.launcher_vest_reserve):
		push_error("Invalid secondary ammunition values for " + key)
		return false
	if definition.secondary_projectile != null and definition.launcher_magazine_size == 0:
		push_error("Projectile secondary attack needs ammunition: " + key)
		return false
	if definition.launcher_magazine_size > 0 and definition.secondary_projectile == null and definition.behavior == null:
		push_error("Secondary ammo needs a projectile or behavior: " + key)
		return false
	pending[key] = definition
	registration_order.append(key)
	_register_point_classes(point_classes)
	call_deferred("finalize")
	return true

func _register_point_classes(point_classes):
	if not point_classes is Array or point_classes.empty():
		return
	var fgd = load("res://addons/qodot/game-definitions/fgd/qodot_fgd.tres")
	if fgd == null:
		return
	for entry in point_classes:
		var point_class = load(entry) if entry is String else entry
		if point_class == null:
			continue
		var exists = false
		for entity in fgd.entity_definitions:
			if entity.get("classname") == point_class.classname:
				exists = true
				break
		if not exists:
			fgd.entity_definitions.append(point_class)

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

func resolve_scene_weapon(weapon_id:String)->int:
	finalize()
	var index = index_for(weapon_id)
	if index < 0:
		push_error("Unknown scene weapon ID: " + weapon_id)
	return index

func has_weapon(key:String)->bool:
	return pending.has(key.to_lower())

func definition_for(index:int):
	return definitions.get(index, null)

func id_for(index:int)->String:
	return names.get(index, "")

func is_custom(index)->bool:
	return typeof(index) == TYPE_INT and definitions.has(index)
