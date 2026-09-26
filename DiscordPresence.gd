extends Node

const APPLICATION_ID = "1550836628509954048"
const ROOT = "user://mod_config/crus_online/discord"
const BRIDGE = "res://MOD_CONTENT/CruS Online/discord/CruSDiscord.exe"
onready var session = get_parent()
onready var bridge = get_parent().get_node("NetworkBridge")
var elapsed = 0.0
var heartbeat = 0.0
var state_path = ""
var helper_pid = -1
var last_state = ""
var level_names = []
var last_error = ""

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	for signal_name in ["status_update", "players_update", "connected_to_server", "disconnected_from_server", "scene_loaded"]:
		session.connect(signal_name, self, "_refresh")
	Global.connect("scene_loaded", self, "_refresh")
	call_deferred("_start")

func _refresh(_value = null):
	call_deferred("_refresh_state")

func _refresh_state():
	if not state_path.empty():
		_write_state()

func _start():
	if OS.get_name() != "Windows":
		set_process(false)
		return
	var directory = Directory.new()
	var directory_error = directory.make_dir_recursive(ROOT)
	if not directory_error in [OK, ERR_ALREADY_EXISTS]:
		last_error = "Cannot create Discord presence directory"
		return
	var file = File.new()
	if file.open(BRIDGE, File.READ) != OK:
		last_error = "Discord helper is missing"
		return
	var data = file.get_buffer(file.get_len())
	file.close()
	var executable = ROOT.plus_file("CruSDiscord-" + file.get_sha256(BRIDGE).substr(0, 16) + ".exe")
	if not file.file_exists(executable):
		if file.open(executable, File.WRITE) != OK:
			last_error = "Cannot extract Discord helper"
			return
		file.store_buffer(data)
		file.close()
	state_path = ROOT.plus_file("presence-" + str(OS.get_process_id()) + ".json")
	_write_state()
	helper_pid = OS.execute(ProjectSettings.globalize_path(executable), [str(OS.get_process_id()), ProjectSettings.globalize_path(state_path), APPLICATION_ID], false, [], false, false)
	if helper_pid <= 0:
		last_error = "Could not start Discord helper"

func _process(delta):
	if state_path.empty():
		return
	elapsed += delta
	heartbeat += delta
	if elapsed >= 0.25:
		elapsed = 0.0
		_read_join()
		_write_state()

func _read_join():
	if session.SteamLobby.get_signal_connection_list("lobby_join_requested").empty():
		return
	var path = state_path + ".join"
	var file = File.new()
	if file.open(path, File.READ) != OK:
		return
	var secret = file.get_as_text()
	file.close()
	Directory.new().remove(path)
	var parts = secret.split(":")
	if parts.size() != 3 or parts[0] != "crus2":
		return
	if not parts[1].is_valid_integer() or int(parts[1]) <= 0:
		return
	if parts[2].length() != 6:
		return
	if session.SteamLobby.get_lobby_id() == int(parts[1]):
		return
	if not session.SteamInit.is_online:
		last_error = "Steam must be online to accept a Discord invite"
		return
	if bridge.check_connection():
		session.leave_server()
	session.SteamLobby.call_deferred("emit_signal", "lobby_join_requested", int(parts[1]), parts[2])

func _level_name(index):
	if level_names.empty():
		for path in Global.LEVEL_META:
			var file = File.new()
			var title = "Unknown Mission"
			if file.open(path, File.READ) == OK:
				var parsed = JSON.parse(file.get_as_text())
				if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
					title = str(parsed.result.get("name", title))
				file.close()
			level_names.append(title)
	return level_names[index] if index >= 0 and index < level_names.size() else "Custom Mission"

func activity():
	var online = bridge.check_connection()
	var scene = Global.current_scene
	var menu_scene = not is_instance_valid(scene) or scene.filename in ["res://Menu/Main_Menu.tscn", "res://MOD_CONTENT/CruS Online/maps/crus_online_lobby.tscn"]
	var in_level = not menu_scene and session._menu_destination.empty() and is_instance_valid(Global.menu) and Global.menu.in_game and Global.loader == null and get_node_or_null("/root/Level") != null
	var index = Global.CURRENT_LEVEL
	var title = _level_name(index) if in_level else "Main Menu"
	var portrait = "level_%02d" % index if in_level and index >= 0 and index < Global.LEVELS.size() else "game_icon"
	var status = "Targets: %d/%d" % [Global.objectives, max(Global.objectives, Global.objectives_total)] if in_level else "Main Menu"
	var difficulty = preload("res://MOD_CONTENT/CruS Online/DifficultyLabel.gd").describe(Global.soul_intact, Global.husk_mode, Global.hope_discarded, Global.punishment_mode, Global.chaos_mode).replace("Host difficulty: ", "")
	var result = {"details": status, "state": "Playing Online" if online else "Playing Singleplayer", "assets": {"large_image": portrait, "large_text": title if in_level else "Cruelty Squad", "small_image": "loading_screen", "small_text": difficulty}, "buttons": [{"label": "Get on Steam", "url": "https://store.steampowered.com/app/1388770/Cruelty_Squad/"}, {"label": "Play Online", "url": "http://purgateam.com/projects/crus-online-reconstructed/index.html"}]}
	if online:
		var capacity = 17
		if bridge.is_steam():
			capacity = 16
			var steam = session.SteamInit.Steam
			if steam.has_method("getLobbyMemberLimit"):
				capacity = max(1, steam.getLobbyMemberLimit(session.SteamLobby.get_lobby_id()))
		result["party"] = {"size": [max(1, session.players.size()), max(capacity, session.players.size())]}
		if bridge.is_steam():
			var lobby_id = session.SteamLobby.get_lobby_id()
			result["party"]["id"] = "crus-steam-" + str(lobby_id)
			if lobby_id > 0 and bridge.is_world_authority() and session.SteamLobby.is_owner() and session.players.size() < capacity and is_instance_valid(Global.menu) and not Global.menu.in_game and Global.loader == null and not Global.cutscene:
				result["secrets"] = {"join": "crus2:%s:%s" % [lobby_id, session.SteamLobby.lobby_code()]}
				result["instance"] = true
				result.erase("buttons")
	return result

func _write_state():
	var serialized = to_json(activity())
	if serialized == last_state and heartbeat < 5.0:
		return
	var file = File.new()
	if file.open(state_path, File.WRITE) != OK:
		last_error = "Cannot update Discord presence"
		return
	file.store_string(serialized)
	file.close()
	last_state = serialized
	heartbeat = 0.0

func _exit_tree():
	if not state_path.empty():
		Directory.new().remove(state_path)
