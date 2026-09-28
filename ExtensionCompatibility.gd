extends Node

signal catalog_ready

const BASE_LEVEL_COUNT = 19
var custom_levels = []
var custom_folders = {}
var initialized = false
var records_loaded = false
var blocked = false
var resetting_cheats = false
var cheats = null
var suppressed = []
onready var Multiplayer = get_parent()

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("initialize")

func modbase():
	return get_node_or_null("/root/Mod/CruS Mod Base")

func initialize():
	if initialized:
		return
	var base = modbase()
	if base != null and not base.data.has("levels") and not base.data.has("debug_level"):
		var base_init = base.get_node_or_null("Init")
		if base_init != null and not base_init.is_connected("modbase_load_complete", self, "initialize"):
			base_init.connect("modbase_load_complete", self, "initialize", [], CONNECT_ONESHOT)
		return
	initialized = true
	if base != null:
		load_custom_levels()
		load_custom_records()
		Global.menu.register_custom_levels()
		ensure_mods_control()
	emit_signal("catalog_ready")
	Multiplayer.Content.resume_join()

func read_json(path):
	var file = File.new()
	if file.open(path, File.READ) != OK:
		return {}
	var parsed = JSON.parse(file.get_as_text())
	file.close()
	return parsed.result if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY else {}

func level_file(folder, value):
	if typeof(value) != TYPE_STRING or value.empty():
		return ""
	return value if value.begins_with("res://") or value.begins_with("user://") else "user://levels/" + folder + "/" + value

func media(folder, value):
	var path = level_file(folder, value)
	if path.empty():
		return null
	if path.begins_with("res://"):
		return load(path) if ResourceLoader.exists(path) else null
	if path.get_extension().to_lower() == "png":
		var image = Image.new()
		if image.load(path) != OK:
			return null
		var texture = ImageTexture.new()
		texture.create_from_image(image, 0)
		return texture
	var audio_script = "res://MOD_CONTENT/CruS Mod Base/lib/GDScriptAudioImport.gd"
	return load(audio_script).new().loadfile(path) if ResourceLoader.exists(audio_script) and File.new().file_exists(path) else null

func load_custom_levels():
	var folders_by_name = {}
	var directory = Directory.new()
	if directory.open("user://levels") == OK:
		directory.list_dir_begin(true, true)
		var folder = directory.get_next()
		while not folder.empty():
			if directory.current_is_dir() and folder != "_debug" and preload("res://MOD_CONTENT/CruS Online/ContentPaths.gd").safe_relative(folder):
				var raw = read_json("user://levels/" + folder + "/level.json")
				if not raw.empty():
					folders_by_name[str(raw.get("name", folder))] = folder
			folder = directory.get_next()
		directory.list_dir_end()
	var sources = [modbase().data.debug_level] if modbase().data.has("debug_level") else modbase().data.get("levels", [])
	for source in sources:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		var scene = str(source.get("scene_path", ""))
		if not ResourceLoader.exists(scene):
			continue
		var name = "_debug" if modbase().data.has("debug_level") else folders_by_name.get(str(source.get("name", "")), "")
		if not preload("res://MOD_CONTENT/CruS Online/ContentPaths.gd").safe_relative(name):
			continue
		var level = source.duplicate(true)
		level["folder"] = name
		level["local_debug"] = name == "_debug"
		custom_folders[scene] = name
		custom_levels.append(level)
		append_level(level)

func custom_rank(value, limits):
	if value >= 99999999:
		return "N"
	if value < limits[0]:
		return "S"
	if value < limits[1]:
		return "A"
	if value < limits[2]:
		return "B"
	return "C"

func load_custom_records():
	var saved = read_json("user://custom_level_times.save")
	for offset in range(custom_levels.size()):
		var index = BASE_LEVEL_COUNT + offset
		var name = str(custom_levels[offset].name)
		for category in [
			["_raw_time", Global.LEVEL_TIMES_RAW, Global.level_ranks, [Global.LEVEL_RANK_S, Global.LEVEL_RANK_A, Global.LEVEL_RANK_B]],
			["_raw_stime", Global.LEVEL_STIMES_RAW, Global.level_stock_ranks, [Global.LEVEL_SRANK_S, Global.LEVEL_RANK_A, Global.LEVEL_RANK_B]],
			["_hell_raw_time", Global.HELL_TIMES_RAW, Global.hell_ranks, [Global.HELL_RANK_S, Global.HELL_RANK_A, Global.HELL_RANK_B]],
			["_hell_raw_stime", Global.HELL_STIMES_RAW, Global.hell_stock_ranks, [Global.HELL_SRANK_S, Global.HELL_RANK_A, Global.HELL_RANK_B]]
		]:
			var value = saved.get(name + category[0])
			if typeof(value) in [TYPE_INT, TYPE_REAL] and value >= 0:
				category[1][index] = value
				category[2][index] = custom_rank(value, [category[3][0][index], category[3][1][index], category[3][2][index]])
		for category in [
			["_string_time", Global.LEVEL_TIMES], ["_string_stime", Global.LEVEL_STIMES],
			["_hell_string_time", Global.HELL_TIMES], ["_hell_string_stime", Global.HELL_STIMES]
		]:
			var value = saved.get(name + category[0])
			if typeof(value) == TYPE_STRING:
				category[1][index] = value
		if typeof(saved.get(name + "_punished")) == TYPE_BOOL:
			Global.LEVEL_PUNISHED[index] = saved[name + "_punished"]
	records_loaded = true

func save_custom_records():
	if not records_loaded or custom_levels.empty():
		return
	var saved = {}
	for offset in range(custom_levels.size()):
		var index = BASE_LEVEL_COUNT + offset
		var name = str(custom_levels[offset].name)
		for category in [
			["_raw_time", Global.LEVEL_TIMES_RAW], ["_string_time", Global.LEVEL_TIMES],
			["_raw_stime", Global.LEVEL_STIMES_RAW], ["_string_stime", Global.LEVEL_STIMES],
			["_hell_raw_time", Global.HELL_TIMES_RAW], ["_hell_string_time", Global.HELL_TIMES],
			["_hell_raw_stime", Global.HELL_STIMES_RAW], ["_hell_string_stime", Global.HELL_STIMES]
		]:
			saved[name + category[0]] = category[1][index]
		saved[name + "_punished"] = Global.LEVEL_PUNISHED[index]
	var file = File.new()
	if file.open("user://custom_level_times.save", File.WRITE) == OK:
		file.store_line(to_json(saved))
		file.close()

func ensure_mods_control():
	var parent = Global.menu.get_node_or_null("Settings/GridContainer/PanelContainer6/VBoxContainer3")
	if parent == null:
		return
	var show_mods = parent.get_node_or_null("ShowMods")
	if show_mods == null:
		show_mods = load("res://MOD_CONTENT/CruS Mod Base/scenes/ShowMods.tscn").instance()
		parent.add_child_below_node(parent.get_node("CenterContainer"), show_mods)
	show_mods.show()

func append_level(level):
	Global.LEVELS.append(level.scene_path)
	Global.LEVEL_META.append(level)
	var picture = level.get("image") if level.get("image") is Texture else media(level.folder, level.get("image"))
	Global.LEVEL_IMAGES.append(picture if picture != null else load("res://Textures/Menu/mystery.png"))
	Global.LEVEL_SONGS.append(level.get("music") if level.get("music") is AudioStream else media(level.folder, level.get("music")))
	Global.LEVEL_AMBIENCE.append(level.get("ambience") if level.get("ambience") is AudioStream else media(level.folder, level.get("ambience")))
	Global.LEVEL_REWARDS.append(int(level.get("reward", 0)))
	var dialogue = level.get("dialogue", ["..."])
	if typeof(dialogue) == TYPE_STRING:
		var file = File.new()
		if file.open(level_file(level.folder, dialogue), File.READ) == OK:
			var parsed = JSON.parse(file.get_as_text())
			dialogue = parsed.result if parsed.error == OK else ["..."]
			file.close()
	elif typeof(dialogue) in [TYPE_INT, TYPE_REAL]:
		dialogue = Global.DIALOGUE.DIALOGUE[int(dialogue)] if int(dialogue) >= 0 and int(dialogue) < Global.DIALOGUE.DIALOGUE.size() else ["..."]
	Global.DIALOGUE.DIALOGUE.append(dialogue if typeof(dialogue) == TYPE_ARRAY and not dialogue.empty() else ["..."])
	Global.STOCKS.POSSIBLE_FISH.append(level.get("fish", ["FISH", "DEAD"]))
	Global.LEVEL_PUNISHED.append(false)
	for array in [Global.LEVEL_TIMES, Global.LEVEL_STIMES, Global.HELL_TIMES, Global.HELL_STIMES]:
		array.append("N/A")
	for array in [Global.LEVEL_TIMES_RAW, Global.LEVEL_STIMES_RAW, Global.HELL_TIMES_RAW, Global.HELL_STIMES_RAW]:
		array.append(99999999)
	for array in [Global.level_ranks, Global.level_stock_ranks, Global.hell_ranks, Global.hell_stock_ranks]:
		array.append("N")
	var ranks = level.get("ranks", {})
	for prefix in ["normal", "hell"]:
		var times = ranks.get(prefix, [0, 0, 0])
		if typeof(times) != TYPE_ARRAY or times.size() != 3:
			times = [0, 0, 0]
		var arrays = [Global.LEVEL_RANK_S, Global.LEVEL_RANK_A, Global.LEVEL_RANK_B, Global.LEVEL_SRANK_S] if prefix == "normal" else [Global.HELL_RANK_S, Global.HELL_RANK_A, Global.HELL_RANK_B, Global.HELL_SRANK_S]
		for index in range(3):
			arrays[index].append(max(0, int(times[index])))
		arrays[3].append(max(0, int(ranks.get(prefix + "_stock_s", 0))))
	Global.menu.LEVEL_NAMES.append(level.name)

func set_scene(scene):
	var index = Global.LEVELS.find(scene)
	if index < 0:
		return false
	Global.CURRENT_LEVEL = index
	return true

func prepare_scene(root):
	if modbase() == null:
		return
	if not Multiplayer.NetworkBridge.check_connection() and not blocked:
		var scene = "res://MOD_CONTENT/CruS Mod Base/scenes/Cheats.tscn"
		if ResourceLoader.exists(scene):
			cheats = load(scene).instance()
			root.add_child(cheats)
	else:
		strip_cheats(root)

func online_selected():
	for menu in get_tree().get_nodes_in_group("MultiplayerMenu"):
		if menu.has_node("CenterContainer/TabContainer/Main") and menu.get_node("CenterContainer").is_visible_in_tree() and menu.get_node("CenterContainer/TabContainer/Main").current_tab != 0:
			return true
	return Multiplayer.NetworkBridge.check_connection()

func strip_cheats(root):
	for node in root.get_children():
		var script = node.get_script()
		var path = script.resource_path.to_lower() if script != null else ""
		if "crus mod base" in path and path.get_file() in ["cheats.gd", "cheats.gdc", "cheatprompt.gd", "cheatprompt.gdc", "noclip.gd", "noclip.gdc", "debug_menu.gd", "debug_menu.gdc", "level_menu.gd", "level_menu.gdc", "implant_menu_ingame.gd", "implant_menu_ingame.gdc"]:
			node.set_process(false)
			node.set_physics_process(false)
			node.set_process_input(false)
			node.set_process_unhandled_input(false)
			if node is CanvasItem:
				node.hide()
			if not suppressed.has(node):
				suppressed.append(node)
		else:
			strip_cheats(node)

func _process(_delta):
	if modbase() == null:
		return
	var active = online_selected()
	if active != blocked:
		blocked = active
		if active:
			resetting_cheats = true
			if is_instance_valid(cheats):
				if cheats.has_method("exit_noclip"):
					cheats.exit_noclip()
				for toggle in [["zombie", "toggle_zombie"], ["psychopass", "toggle_vanish"], ["magpump", "toggle_infinite_magazine"], ["hoptoit", "toggle_infinite_jump"], ["kitted", "toggle_infinite_arm_aug"], ["friday", "toggle_npc_ffa"]]:
					if cheats.enabled.has(toggle[0]):
						cheats.call(toggle[1])
				if cheats.disable_ai:
					cheats.toggle_disable_ai()
			resetting_cheats = false
			strip_cheats(get_tree().root)
		else:
			for node in suppressed:
				if is_instance_valid(node):
					node.set_process(true)
					node.set_process_input(true)
					node.set_physics_process(true)
			suppressed.clear()
