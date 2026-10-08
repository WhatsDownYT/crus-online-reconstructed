extends Node

signal catalog_changed

const VALID_SLOTS = ["Head", "Torso", "Arms", "Legs"]
const BOOLEAN_MODIFIERS = ["ricochet", "grav", "orbsuit", "ski", "market_enhancer", "helmet", "nightvision", "terror", "triple_jump", "jetpack", "shrink", "slowfall", "sensor", "instadeath", "stealth", "climb", "explosive_shield", "nightmare", "holy", "fishing_bonus", "grapple", "radio", "cursed_torch", "regen_ammo", "chemical_shield", "bouncy", "thrust", "toxic_shield", "skullgun", "he_grenade", "kick_improvement", "flechette_grenade", "sleep_grenade", "multiplayer_camo", "multiplayer_stealth", "multiplayer_sedative", "multiplayer_first_aid", "multiplayer_cursed_torch", "multiplayer_augmented_arms"]
const NUMBER_MODIFIERS = ["armor", "speed_bonus", "ammo_bonus", "jump_bonus", "double_jump", "throw_bonus", "zoom_bonus", "healing", "camo"]
const SLOT_PROPERTIES = {"Head": "head", "Torso": "torso", "Arms": "arms", "Legs": "legs"}

var pending = {}
var registration_order = []
var instances = {}
var behaviors = {}
var active = {}
var active_player = null

func _ready():
	call_deferred("finalize")

func load_bundled_implants():
	var manifest = File.new()
	if manifest.open("res://MOD_CONTENT/CruS Online/implants/catalog.json", File.READ) != OK:
		push_error("Could not open the CruS Online implant catalog")
		return
	var entries = parse_json(manifest.get_as_text())
	manifest.close()
	if not entries is Array:
		push_error("Invalid CruS Online implant catalog")
		return
	for path in entries:
		if typeof(path) == TYPE_STRING:
			var definition = load(path)
			if definition != null:
				if definition.discoverable and not _source_level_declares_implant(str(definition.source_level), str(definition.implant_id).to_lower()):
					continue
				register_implant(definition)

func register_implant(definition):
	if not definition is Resource or definition.get("implant_id") == null:
		push_error("Invalid custom implant definition")
		return false
	var key = str(definition.implant_id).strip_edges().to_lower()
	var display = str(definition.display_name).strip_edges()
	if key.find(":") < 1 or key.ends_with(":") or pending.has(key) or display.empty() or not VALID_SLOTS.has(definition.slot) or definition.price < 0 or definition.icon == null:
		push_error("Invalid or duplicate custom implant: " + key)
		return false
	if definition.behavior != null and not definition.behavior.can_instance():
		push_error("Cannot instantiate custom implant behavior: " + key)
		return false
	for modifier in definition.modifiers:
		var value = definition.modifiers[modifier]
		if BOOLEAN_MODIFIERS.has(modifier):
			if typeof(value) != TYPE_BOOL:
				push_error("Invalid boolean implant modifier: " + str(modifier))
				return false
		elif NUMBER_MODIFIERS.has(modifier):
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_REAL:
				push_error("Invalid numeric implant modifier: " + str(modifier))
				return false
		else:
			push_error("Unsupported implant modifier: " + str(modifier))
			return false
	for implant in Global.implants.IMPLANTS:
		if implant != null and implant.i_name.to_lower() == display.to_lower():
			push_error("Duplicate implant display name: " + display)
			return false
	for other in pending.values():
		if str(other.display_name).to_lower() == display.to_lower():
			push_error("Duplicate implant display name: " + display)
			return false
	if definition.discoverable and definition.point_class == null:
		push_error("Discoverable implant needs a Qodot pickup point class: " + key)
		return false
	if definition.discoverable and not _source_level_declares_implant(str(definition.source_level), key):
		push_error("Discoverable implant needs its source mission and reciprocal dependency: " + key)
		return false
	pending[key] = definition
	registration_order.append(key)
	_register_point_class(definition.point_class)
	call_deferred("finalize")
	return true

func _source_level_declares_implant(folder:String, key:String)->bool:
	if folder.empty() or folder == "." or folder == ".." or folder.find("/") != -1 or folder.find("\\") != -1:
		return false
	var path = "user://levels/" + folder + "/level.json"
	var file = File.new()
	if file.open(path, File.READ) != OK:
		return false
	var metadata = parse_json(file.get_as_text())
	file.close()
	if not metadata is Dictionary or str(metadata.get("name", "")) != folder or not metadata.get("required_implants", []) is Array or not metadata.required_implants.has(key):
		return false
	var scene = str(metadata.get("level_scene", ""))
	if scene.empty():
		return false
	if scene.begins_with("res://") or scene.begins_with("user://"):
		return ResourceLoader.exists(scene) or File.new().file_exists(scene)
	return File.new().file_exists("user://levels/" + folder + "/" + scene)

func _register_point_class(point_class):
	if point_class == null:
		return
	var fgd = load("res://addons/qodot/game-definitions/fgd/qodot_fgd.tres")
	if fgd == null:
		push_error("Could not register custom implant map entity")
		return
	for entity in fgd.entity_definitions:
		if entity.get("classname") == point_class.classname:
			return
	fgd.entity_definitions.append(point_class)

func finalize():
	if not is_instance_valid(Global.implants) or Global.implants.IMPLANTS.empty():
		return
	var changed = false
	for key in registration_order:
		if instances.has(key):
			continue
		var definition = pending[key]
		var implant = Global.implants.create_custom_implant()
		implant.custom_id = key
		implant.i_name = definition.display_name
		implant.explanation = definition.description
		implant.price = definition.price
		implant.hidden = definition.discoverable
		implant.texture = definition.icon
		implant.set(SLOT_PROPERTIES[definition.slot], true)
		for modifier in definition.modifiers:
			implant.set(modifier, definition.modifiers[modifier])
		Global.implants.IMPLANTS.append(implant)
		instances[key] = implant
		if definition.behavior != null:
			behaviors[key] = definition.behavior.new()
		changed = true
	if changed:
		emit_signal("catalog_changed")

func definition_for(key:String):
	return pending.get(key.to_lower(), null)

func implant_for(key:String):
	return instances.get(key.to_lower(), null)

func _call_behavior(implant, method, args):
	if implant == null or implant.custom_id.empty():
		return
	var behavior = behaviors.get(implant.custom_id)
	if behavior != null and behavior.has_method(method):
		behavior.callv(method, args)

func _process(delta):
	if instances.size() < pending.size():
		finalize()
	if not is_instance_valid(Global.implants):
		return
	var player = Global.player if is_instance_valid(Global.player) and is_instance_valid(Global.menu) and Global.menu.in_game and not Global.player.dead else null
	var slots = ["head_implant", "torso_implant", "arm_implant", "leg_implant"]
	for slot in slots:
		var current = Global.implants.get(slot) if player != null else null
		if current != null and current.custom_id.empty():
			current = null
		var previous = active.get(slot)
		if previous != current or active_player != player:
			if previous != null and is_instance_valid(active_player):
				_call_behavior(previous, "on_unequip", [active_player, previous])
			if current != null:
				_call_behavior(current, "on_equip", [player, current])
			active[slot] = current
		if current != null:
			_call_behavior(current, "on_process", [player, current, delta])
			var action = str(pending[current.custom_id].input_action)
			if not action.empty() and not get_tree().paused and InputMap.has_action(action) and Input.is_action_just_pressed(action):
				_call_behavior(current, "on_use", [player, current])
	active_player = player
