extends Node

var version = "Beta v0.3"

enum errorType {UNKNOW, TIME_OUT, WRONG_PASSWORD, WRONG_VERSION, PASSWORD_REQUIRE, SERVER_CLOSED, UPNP_ERROR, PLAYER_CONNECTED}

var profile_loaded = false
var playerInfo = {
	"nickname": "MT Foxtrot",
	"color": "ff00ff",
	"image": "null",
	"skinPath": "res://Textures/Misc/mainguy_clothes.png"
}

var hostSettings = {
	"bannedImplants" : [],
	"map" : null,
	"helpTimer": 15,
	"canRespawn": false,
	"changeModeOnDeath": true,
	"shareDifficulty": false,
	"friendlyFire": true,
	"useVoiceChat": true,
	"proximityVoiceChat": true,
	"hearDeadPlayers": false
}

var config = {
	"lastIp": "127.0.0.1",
	"lastPort": 25567,
	"hostPort": 25567,
	"hostPassword": "",
	"tickRate": 3,
	"helpTimer": 15,
	"canRespawn": false,
	"changeModeOnDeath": true,
	"shareDifficulty": false,
	"friendlyFire": true,
	"useVoiceChat": true,
	"proximityVoiceChat": true,
	"hearDeadPlayers": false
}

var password = ""

var passwordEntered = false

var dataLoaded = false

var players = {}

var playerPuppet = null
var _announce_difficulty = false
var _menu_destination = ""

func _public_players():
	var result = {}
	for peer in players:
		result[peer] = {}
		for field in ["nickname", "color", "image", "skinPath"]:
			result[peer][field] = players[peer].get(field, playerInfo[field])
	return result

onready var DeathScreen = Global.get_node('DeathScreen')

onready var Players = $Players
onready var Menu = $Menu
onready var Hint = $Hint
onready var UDPLagger = $UDPLagger
onready var NetworkBridge = $NetworkBridge

onready var SteamInit = $SteamInit
onready var SteamLobby = $SteamInit/SteamLobby
onready var SteamNetwork = $SteamInit/SteamNetwork

signal status_update(status)
signal players_update(data)

signal host_tick()

signal connected_to_server()
signal disconnected_from_server(error)

signal throw_error(error)




func _notification(what):
	match what:
		NOTIFICATION_CRASH:
			push_error("[CRUS ONLINE / MAIN]: CRASH DETECTED")

var Flow
var Voice

func _ready():
	Flow = preload("res://MOD_CONTENT/CruS Online/SessionFlow.gd").new()
	Flow.name = "SessionFlow"
	add_child(Flow)
	Voice = preload("res://MOD_CONTENT/CruS Online/VoiceChat.gd").new()
	Voice.name = "VoiceChat"
	add_child(Voice)
	var discord_presence = preload("res://MOD_CONTENT/CruS Online/DiscordPresence.gd").new()
	discord_presence.name = "DiscordPresence"
	add_child(discord_presence)
	var cancer_replication = preload("res://MOD_CONTENT/CruS Online/CancerReplication.gd").new()
	cancer_replication.name = "CancerReplication"
	add_child(cancer_replication)
	SteamNetwork.register_rpcs(self,[
		["set_packages_count", SteamNetwork.PERMISSION.SERVER],
		["ping_set", SteamNetwork.PERMISSION.SERVER],
		["disconnect_client", SteamNetwork.PERMISSION.SERVER],
		["password_not_require", SteamNetwork.PERMISSION.SERVER],
		["password_checked", SteamNetwork.PERMISSION.SERVER],
		["client_connect_init", SteamNetwork.PERMISSION.SERVER],
		["sync_players", SteamNetwork.PERMISSION.SERVER],
		["goto_menu_client", SteamNetwork.PERMISSION.SERVER],
		["goto_scene_client", SteamNetwork.PERMISSION.SERVER],
		["scene_loaded_signal", SteamNetwork.PERMISSION.SERVER],
		["sync_load_progress", SteamNetwork.PERMISSION.SERVER],
		["set_death_label", SteamNetwork.PERMISSION.SERVER],
		["hide_death_screen", SteamNetwork.PERMISSION.SERVER],
		["ping_host", SteamNetwork.PERMISSION.ALL],
		["password_require_check", SteamNetwork.PERMISSION.ALL],
		["connect_init", SteamNetwork.PERMISSION.ALL],
		["load_check", SteamNetwork.PERMISSION.ALL],
		["_player_died", SteamNetwork.PERMISSION.ALL],
		["sync_player_life", SteamNetwork.PERMISSION.SERVER],
		["apply_team_wipe", SteamNetwork.PERMISSION.SERVER],
		["reward_npc_kill", SteamNetwork.PERMISSION.SERVER],
		["spawn_enemy_weapon", SteamNetwork.PERMISSION.SERVER],
		["_player_respawn", SteamNetwork.PERMISSION.ALL],
		["client_peer_connect", SteamNetwork.PERMISSION.SERVER],
		["sync_mission_state", SteamNetwork.PERMISSION.SERVER],
		["sync_host_settings", SteamNetwork.PERMISSION.SERVER],
		["notify_host_difficulty", SteamNetwork.PERMISSION.SERVER],
		["request_menu_exit", SteamNetwork.PERMISSION.ALL]
	])
	
	pause_mode = Node.PAUSE_MODE_PROCESS
	
	get_tree().get_nodes_in_group("MultiplayerMenu")[0].data_init()

	get_tree().connect("network_peer_connected", self, "connected")
	get_tree().connect("network_peer_disconnected", self, "disconnected")
	get_tree().connect("server_disconnected", self, "host_session_ended", [], CONNECT_DEFERRED)
	
	SteamNetwork.connect("all_peers_connected", self, "steam_peers_connect")
	SteamNetwork.connect("host_left", self, "host_session_ended", [], CONNECT_DEFERRED)
	SteamLobby.connect("player_left_lobby", self, "peer_update")
	
	Global.connect("scene_loaded", self, "_scene_loaded")

var tick = 0

var packages_count = 0

var packages_inspector = false
var last_ping_ms = 0

func peer_update(steam_id):
	if players.has(steam_id):
		if is_instance_valid(Global.player) and is_instance_valid(Global.UI):
			Global.UI.notify(players[steam_id].nickname + " disconnected", Color(1, 0, 0))
		
		players.erase(steam_id)
	
	Players.sync_players()
	if NetworkBridge.is_world_authority():
		NetworkBridge.n_rpc(self, "sync_players", [_public_players()])

func _input(event):
	if event is InputEventKey and not event.echo and event.pressed:
		var key = event.scancode

		match key:
			KEY_F1:
				$Debug.visible = !$Debug.visible
			KEY_F2:
				print("[CRUS ONLINE / DEBUG] players: ")
				for player in players:
					print(str(player) + ": ", players[player])
			KEY_F3:
				packages_inspector = !packages_inspector
				NetworkBridge.debug = packages_inspector
				$Debug/VBoxContainer/PackagesDebugList.visible = packages_inspector

func _physics_process(delta):
	_update_menu_background()
	if NetworkBridge.is_lan():
		if get_tree().network_peer != null and get_tree().network_peer.get_connection_status() == 0:
			host_session_ended()
		
	if NetworkBridge.check_connection() and NetworkBridge.n_is_network_master() and tick % config.tickRate == 0:
		emit_signal("host_tick")
		tick = 0
	tick += 1

puppet func set_packages_count(id, value):
	$Debug/VBoxContainer/PPT.text = "Packages per sec: " + str(value)

func ping_check():
	$Debug/VBoxContainer/FPS.text = "FPS: " + str(Engine.get_frames_per_second())
	print("[CruS transport metrics] ", SteamNetwork.diagnostics())
	
	if NetworkBridge.check_connection():
		if NetworkBridge.is_steam() and (not SteamNetwork._peers.has(SteamInit.steam_id) or not SteamNetwork._peers[SteamInit.steam_id].connected):
			return
		if not NetworkBridge.n_is_network_master(self):
			NetworkBridge.n_rpc(self, "ping_host", [OS.get_ticks_msec()])
		else:
			$Debug/VBoxContainer/PPT.text = "Packages per sec: " + str(packages_count + 1)
			NetworkBridge.n_rpc(self, "set_packages_count", [packages_count])
			packages_count = 0
			if packages_inspector:
				NetworkBridge.print_debug_list()

master func ping_host(id, recived_ping):
	NetworkBridge.n_rpc_id(self, id, "ping_set", [recived_ping])

puppet func ping_set(id, recived_ping):
	last_ping_ms = max(0, OS.get_ticks_msec() - recived_ping)
	$Debug/VBoxContainer/Ping.text = "Ping: " + str(OS.get_ticks_msec() - recived_ping)

func clear_connection(recivedError):
	emit_signal("disconnected_from_server", recivedError)
	push_error("[CRUS ONLINE / MAIN]: ERROR " + str(recivedError))
	
	leave_server()

func apply_host_settings():
	hostSettings.helpTimer = config.helpTimer
	hostSettings.canRespawn = config.canRespawn
	hostSettings.changeModeOnDeath = config.changeModeOnDeath
	hostSettings.friendlyFire = config.friendlyFire
	hostSettings.shareDifficulty = config.shareDifficulty
	for key in ["useVoiceChat", "proximityVoiceChat", "hearDeadPlayers"]:
		hostSettings[key] = config[key]
	if NetworkBridge.check_connection() and NetworkBridge.is_world_authority():
		NetworkBridge.n_rpc(self, "sync_host_settings", [hostSettings])

puppet func sync_host_settings(id, settings):
	if NetworkBridge.request_sender(id) != NetworkBridge.get_host_id():
		return
	hostSettings = settings.duplicate(true)

func host_server():
	apply_host_settings()
	if NetworkBridge.is_lan():
		hostSettings.helpTimer = config.helpTimer
		hostSettings.canRespawn = config.canRespawn
		hostSettings.changeModeOnDeath = config.changeModeOnDeath
		
		if UDPLagger.enabled:
			UDPLagger.setup()
		
		$Debug/VBoxContainer/Ping.text = "Ping: 0"
		$Debug/VBoxContainer/GameType.text = "Player is host"
		
		var server = NetworkedMultiplayerENet.new()
		server.create_server(config.hostPort, 16)
		get_tree().set_network_peer(server)

		players[1] = playerInfo.duplicate(true)
		
		emit_signal("players_update", players)
		emit_signal("status_update", "Hosting server")
		
		dataLoaded = true
		print("[CRUS ONLINE / MAIN]: Server hosted")

func join_to_server(ip, port):
	if NetworkBridge.is_lan():
		config.lastIp = ip
		config.lastPort = port
		
		$Debug/VBoxContainer/GameType.text = "Player is client"
		
		var client = NetworkedMultiplayerENet.new()
		client.create_client(ip,port)
		get_tree().set_network_peer(client)
		
		print("[CRUS ONLINE / MAIN]: Client try to connect")

func leave_server():
	if is_instance_valid(Voice):
		Voice.reset_session()
	if is_instance_valid(Flow):
		Flow.reset_session()
	_announce_difficulty = false
	player_scene_loaded = true
	loaded_players.clear()
	died_players.clear()
	team_wipe_applied = false
	playerPuppet = null
	$RestartTimer.stop()
	if is_connected("host_tick", self, "check_players_load"):
		disconnect("host_tick", self, "check_players_load")
	$SyncLoad.hide()
	DeathScreen.hide()
	Menu.hide()
	Menu.set_process_input(false)
	Global.menu.set_process_input(true)
	get_tree().paused = false
	$CancerReplication.reset(SteamNetwork.scene_epoch + 1)
	dataLoaded = false
	players = {}
	
	$Debug/VBoxContainer/GameType.text = "Player is not connected"
	$Debug/VBoxContainer/PPT.text = "Packages per sec: 0"
	$Debug/VBoxContainer/Ping.text = "Ping: 0"
	
	emit_signal("status_update", "Offline")
	emit_signal("players_update", players)
	
	if NetworkBridge.is_lan():
		get_tree().network_peer = null
	else:
		SteamLobby.leave_lobby()
	
	print("[CRUS ONLINE / MAIN]: Server leaved")











func steam_peers_connect():
	apply_host_settings()
	emit_signal("status_update", "Lobby owner")
	
	if str(playerInfo.nickname).strip_edges().empty():
		playerInfo.nickname = SteamInit.steam_username
	players[NetworkBridge.get_host_id()] = playerInfo.duplicate(true)
	
	$Debug/VBoxContainer/GameType.text = "Player is host"
	NetworkBridge.n_rpc(self, "client_peer_connect")

puppet func client_peer_connect(id):
	emit_signal("status_update", "Connected to Lobby")
	$Debug/VBoxContainer/GameType.text = "Player is client"
	
	if str(playerInfo.nickname).strip_edges().empty():
		playerInfo.nickname = SteamInit.steam_username
	NetworkBridge.n_rpc(self, "connect_init", [password, version, playerInfo])

puppet func disconnected(id):
	if NetworkBridge.is_lan():
		var playerPuppet = get_node_or_null("Players/" + str(id))
		
		if playerPuppet != null:
			playerPuppet.queue_free()
		
		if players.has(id):
			if is_instance_valid(Global.player) and is_instance_valid(Global.UI):
				Global.UI.notify(players[id].nickname + " disconnected", Color(1, 0, 0))
		
		players.erase(id)
		if is_instance_valid(Flow):
			Flow.waiting_peers.erase(id)
			Flow.check_team_wipe()
		emit_signal("players_update", players)
		print("[CRUS ONLINE / MAIN]: Disconnected")

puppet func connected(id):
	if NetworkBridge.is_lan():
		if not dataLoaded:
			NetworkBridge.n_rpc(self, "password_require_check", [passwordEntered])
			print("[CRUS ONLINE / CLIENT]: Connect Init")

puppet func disconnect_client(id, recivedError):
	clear_connection(recivedError)
	
	passwordEntered = false
	password = ""

master func password_require_check(id, recivedPasswordEntered):
	if recivedPasswordEntered:
		NetworkBridge.n_rpc_id(self, id, "password_checked")
	else:
		if config.hostPassword != "":
			NetworkBridge.n_rpc_id(self, id, "disconnect_client", [errorType.PASSWORD_REQUIRE])
		else:
			NetworkBridge.n_rpc_id(self, id, "password_not_require")

puppet func password_not_require(id):
		password = ""
		NetworkBridge.n_rpc(self, "connect_init", [password, version, playerInfo])

puppet func password_checked(id):
	NetworkBridge.n_rpc(self, "connect_init", [password, version, playerInfo])

master func connect_init(id, recivedPassword, recivedVersion, recivedPlayerInfo):
	if recivedVersion != version:
		NetworkBridge.n_rpc_id(self, id, "disconnect_client", [errorType.WRONG_VERSION])
	else:
		if recivedPassword == config.hostPassword:
			NetworkBridge.n_rpc_id(self, id, "client_connect_init", [hostSettings, _public_players()])
			host_add_player(id, recivedPlayerInfo)
			emit_signal("throw_error", errorType.PLAYER_CONNECTED)
			print("[CRUS ONLINE / HOST]: Client Connect Init")
		else:
			NetworkBridge.n_rpc_id(self, id, "disconnect_client", [errorType.WRONG_PASSWORD])

puppet func client_connect_init(id, recivedHostSettings, recivedPlayerInfo):
	players = recivedPlayerInfo
	hostSettings = recivedHostSettings
	
	dataLoaded = true
	
	if NetworkBridge.is_lan():
		passwordEntered = false
		password = ""

		emit_signal("status_update", "Connected to server")
		emit_signal("connected_to_server")
		
		print("[CRUS ONLINE / CLIENT]: Player connected")

remote func connect_notify(id, nickname):
	Global.UI.notify(nickname + " connected", Color(1, 0, 0))

func host_add_player(id, info):
	if not players.has(id):
		players[id] = info
		NetworkBridge.n_rpc(self, "sync_players", [_public_players()])
		Flow.send_world(id)
		print("[CRUS ONLINE / HOST]: Sync player info")
		
		emit_signal("players_update", players)

func host_remove_player(id):
	if players.has(id):
		players.erase(id)
		Flow.waiting_peers.erase(id)
		Flow.check_team_wipe()
		Players.sync_players()
		
		NetworkBridge.n_rpc(self, "sync_players", [_public_players()])

puppet func sync_players(id, info):
	players = info
	for avatar in Players.get_children():
		var peer = int(avatar.name)
		if players.has(peer):
			players[peer]["puppet"] = avatar
	emit_signal("players_update", players)
	
	Players.sync_players()
	
	print("[CRUS ONLINE / CLIENT]: Player info synced")



func goto_menu_host(levelFinished = false, level_select = false):
	if levelFinished:
		Flow.finish_mission(true)
		return
	Flow.clear_result()
	_prepare_menu_return(level_select)
	_announce_difficulty = false
	SteamNetwork.begin_scene(SteamNetwork.scene_epoch + 1)
	$CancerReplication.reset(SteamNetwork.scene_epoch)
	$RestartTimer.stop()
	var menuPath = get_menu_scene()
	
	DeathScreen.hide()
	
	if levelFinished:
		menuPath = level_finished()
	
	get_tree().paused = false
	
	Global.cutscene = false
	Global.border.show()
	
	enable_menu()
	
	if NetworkBridge.check_connection():
		if NetworkBridge.is_lan():
			get_tree().network_peer.refuse_new_connections = false
		else:
			SteamInit.Steam.setLobbyJoinable(SteamLobby.get_lobby_id(), true)
	
	if not level_select:
		Global.CURRENT_LEVEL = 0
	Global.goto_scene(menuPath)
	NetworkBridge.n_rpc(self, "goto_menu_client", [levelFinished, SteamNetwork.scene_epoch, level_select])
	print("[CRUS ONLINE / HOST]: Goto to menu")
	
	Players.remove_players()

puppet func goto_menu_client(id, levelFinished = false, epoch = -1, level_select = false):
	var already_in_menu = not Global.menu.in_game and not Global.cutscene
	SteamNetwork.begin_scene(SteamNetwork.scene_epoch + 1 if epoch < 0 else epoch)
	$CancerReplication.reset(SteamNetwork.scene_epoch)
	$RestartTimer.stop()
	if already_in_menu:
		return
	Flow.clear_result()
	_prepare_menu_return(level_select)
	var menuPath = get_menu_scene()
	
	DeathScreen.hide()
	
	if levelFinished:
		menuPath = level_finished()
	
	get_tree().paused = false
	
	Global.cutscene = false
	Global.border.show()
	
	enable_menu()
	if not level_select:
		Global.CURRENT_LEVEL = 0
	Global.goto_scene(menuPath)
	print("[CRUS ONLINE / CLIENT]: Goto to menu")
	
	Players.remove_players()

func level_finished():
	if Global.player.weapon.weapon1 != null:
		if not Global.WEAPONS_UNLOCKED[Global.player.weapon.weapon1]:
			Global.WEAPONS_UNLOCKED[Global.player.weapon.weapon1] = true
	
	if Global.player.weapon.weapon2 != null:
		if not Global.WEAPONS_UNLOCKED[Global.player.weapon.weapon2]:
			Global.WEAPONS_UNLOCKED[Global.player.weapon.weapon2] = true
	
	if Global.CURRENT_LEVEL + 1 > Global.LEVELS_UNLOCKED and Global.CURRENT_LEVEL + 1 <= Global.L_PUNISHMENT:
		Global.LEVELS_UNLOCKED = Global.CURRENT_LEVEL + 1
		Global.LEVELS_UNLOCKED = clamp(Global.LEVELS_UNLOCKED, 1, 12)
	
	if Global.CURRENT_LEVEL == Global.L_PUNISHMENT:
		Global.ending_1 = true
		Global.water_material.set_shader_param("albedoTex", Global.red_water)
	
	if Global.punishment_mode:
		Global.money += Global.LEVEL_REWARDS[Global.CURRENT_LEVEL] * 2
	else :
		Global.money += Global.LEVEL_REWARDS[Global.CURRENT_LEVEL]
	if Global.punishment_mode:
		if not Global.LEVEL_PUNISHED[Global.CURRENT_LEVEL] and not Global.hope_discarded:
			Global.set_soul()
		Global.LEVEL_PUNISHED[Global.CURRENT_LEVEL] = true
	if Global.levels_completed() and Global.BONUS_UNLOCK.find("END") == - 1:
		Global.BONUS_UNLOCK.append("END")
	Global.save_game()
	
	if Global.CURRENT_LEVEL == Global.L_PUNISHMENT:
		return "res://Cutscenes/CutsceneEnd1.tscn"
	elif Global.CURRENT_LEVEL == Global.L_HQ:
		Global.ending_2 = true
		Global.save_game()
		Global.character_mat.set_shader_param("albedoTex", load("res://Textures/NPC/bosssguy_clothes.png"))
		return "res://Cutscenes/CutsceneEnd2.tscn"
	elif Global.CURRENT_LEVEL == 18:
		Global.ending_3 = true
		Global.save_game()
		return "res://Cutscenes/CutsceneEnd3.tscn"
	else:
		return get_menu_scene()



signal scene_loaded()

var loaded_players = []
var player_scene_loaded = true

func goto_scene_host(scene):
	_menu_destination = ""
	if not NetworkBridge.check_connection():
		Global.cutscene = false
		Global.border.show()
		game_init(scene)
		return
	Flow.prepare_mission()
	_announce_difficulty = not hostSettings.get("shareDifficulty", false)
	SteamNetwork.begin_scene(SteamNetwork.scene_epoch + 1)
	sync_load_progress(null, 0, players.size(), SteamNetwork.scene_epoch)
	$CancerReplication.reset(SteamNetwork.scene_epoch)
	$RestartTimer.stop()
	hostSettings.map = scene
	
	died_players = []
	team_wipe_applied = false
	loaded_players = []
	player_scene_loaded = false
	
	Global.cutscene = false
	Global.border.show()
	
	disable_menu()
	
	if NetworkBridge.is_lan():
		get_tree().network_peer.refuse_new_connections = true
	else:
		SteamInit.Steam.setLobbyJoinable(SteamLobby.get_lobby_id(), false)
		
	Global.goto_scene(scene)
	NetworkBridge.n_rpc(self, "goto_scene_client", [scene, Global.CURRENT_LEVEL, SteamNetwork.scene_epoch])
	print("[CRUS ONLINE / HOST]: Goto to scene [" + scene + "]")
	
	Players.load_players()

puppet func goto_scene_client(id, scene, level, epoch = -1):
	_menu_destination = ""
	Flow.clear_result()
	Flow.waiting_peers.clear()
	died_players.clear()
	team_wipe_applied = false
	SteamNetwork.begin_scene(SteamNetwork.scene_epoch + 1 if epoch < 0 else epoch)
	sync_load_progress(null, 0, players.size(), SteamNetwork.scene_epoch)
	$CancerReplication.reset(SteamNetwork.scene_epoch)
	$RestartTimer.stop()
	player_scene_loaded = false
	
	Global.cutscene = false
	Global.border.show()
	
	disable_menu()
	Global.CURRENT_LEVEL = level
	Global.goto_scene(scene)
	print("[CRUS ONLINE / CLIENT]: Goto to scene [" + scene + "]")
	
	Players.load_players()

func _scene_loaded():
	if _menu_destination != "":
		var level_select = _menu_destination == "level_select"
		_menu_destination = ""
		if not Global.cutscene:
			Global.menu.open_online_destination(level_select)
		return
	if not NetworkBridge.check_connection():
		$SyncLoad.hide()
		player_scene_loaded = true
		emit_signal("scene_loaded")
		return
	if not player_scene_loaded:
		$SyncLoad.rect_scale = Vector2(Global.resolution[0] / 1280 ,Global.resolution[1] / 720 )
		$SyncLoad.show()
		player_scene_loaded = true
		get_tree().paused = true
		
		if NetworkBridge.n_is_network_master(self):
			loaded_players.append(NetworkBridge.get_host_id())
			connect("host_tick", self, "check_players_load")
		else:
			NetworkBridge.n_rpc(self, "load_check")

func check_players_load():
	var is_players_loaded = true
	var ready_count = 0

	for player in players:
		if not loaded_players.has(player):
			is_players_loaded = false
		else:
			ready_count += 1
	var progress_key = "%s:%s:%s" % [SteamNetwork.scene_epoch, ready_count, players.size()]
	if progress_key != _load_progress_key:
		_load_progress_key = progress_key
		sync_load_progress(null, ready_count, players.size(), SteamNetwork.scene_epoch)
		NetworkBridge.n_rpc(self, "sync_load_progress", [ready_count, players.size(), SteamNetwork.scene_epoch])
	
	if is_players_loaded:
		disconnect("host_tick", self, "check_players_load")
		
		print("[CRUS ONLINE / HOST]: Scene loaded")
		
		get_tree().paused = false
		$SyncLoad.hide()
		if Global.CURRENT_LEVEL == 18:
			Global.objectives = 0
			Global.objective_complete = true
		publish_mission_state()
		emit_signal("scene_loaded")
		NetworkBridge.n_rpc(self, "scene_loaded_signal")
		if _announce_difficulty:
			_announce_difficulty = false
			var message = preload("res://MOD_CONTENT/CruS Online/DifficultyLabel.gd").describe(Global.soul_intact, Global.husk_mode, Global.hope_discarded, Global.punishment_mode, Global.chaos_mode)
			notify_host_difficulty(null, message)
			NetworkBridge.n_rpc(self, "notify_host_difficulty", [message])

puppet func notify_host_difficulty(id, message):
	if NetworkBridge.check_connection() and not hostSettings.get("shareDifficulty", false) and typeof(message) == TYPE_STRING and is_instance_valid(Global.UI):
		Global.UI.notify(message, Color(1, 1, 1))

func publish_mission_state():
	if NetworkBridge.check_connection() and NetworkBridge.is_world_authority():
		NetworkBridge.n_rpc(self, "sync_mission_state", [Global.objectives, Global.objective_complete, Global.objectives_total])

puppet func sync_mission_state(id, remaining, complete, total = -1):
	if typeof(remaining) != TYPE_INT or remaining < 0 or typeof(complete) != TYPE_BOOL:
		return
	if typeof(total) != TYPE_INT or total < -1 or (total >= 0 and total < remaining):
		return
	var previous_remaining = Global.objectives
	var was_complete = Global.objective_complete
	Global.objectives = remaining
	Global.objectives_total = total if total >= 0 else max(Global.objectives_total, remaining)
	Global.objective_complete = complete
	if remaining < previous_remaining and Global.UI != null:
		Global.UI.notify("Target Eliminated", Color(1, 0, 0))
	if complete and not was_complete and Global.UI != null:
		Global.UI.notify("All Objectives Complete. Locate the exit.", Color(1, 0, 1))

var _load_progress_key = ""

puppet func sync_load_progress(id, ready_count, total, epoch):
	if epoch != SteamNetwork.scene_epoch or typeof(ready_count) != TYPE_INT or typeof(total) != TYPE_INT or ready_count < 0 or ready_count > total:
		return
	$SyncLoad/Center/Label.text = "Online synchronization\nPlease wait\n\n(%d/%d)" % [ready_count, total]

master func load_check(id):
	id = NetworkBridge.request_sender(id)
	if NetworkBridge.is_world_authority() and players.has(id) and not loaded_players.has(id):
		loaded_players.append(id)

puppet func scene_loaded_signal(id):
	get_tree().paused = false
	$SyncLoad.hide()
	emit_signal("scene_loaded")
	
	print("[CRUS ONLINE / CLIENT]: Scene loaded")



var died_players = []
var team_wipe_applied = false

func player_died():
	if NetworkBridge.check_connection() and NetworkBridge.n_is_network_master(self):
		_player_died(null, true)
	else:
		NetworkBridge.n_rpc(self, "_player_died")

master func _player_died(id, host = false):
	if not NetworkBridge.is_world_authority():
		return
	id = NetworkBridge.request_sender(id)
	if not players.has(id):
		return
	if died_players.has(id):
		return
	died_players.append(id)
	sync_player_life(null, id, true)
	NetworkBridge.n_rpc(self, "sync_player_life", [id, true])

	var all_player_died = true

	for player in players:
		if not died_players.has(player):
			all_player_died = false
	
	if is_instance_valid(Flow):
		Flow.check_team_wipe()
		return
	if all_player_died and not team_wipe_applied:
		apply_team_wipe(null)
		NetworkBridge.n_rpc(self, "apply_team_wipe")
	if all_player_died and not hostSettings.canRespawn:
		print("[CRUS ONLINE / HOST]: All players is dead lol")
		$RestartTimer.start()
		set_death_label(null)
		NetworkBridge.n_rpc(self, "set_death_label")

puppet func spawn_enemy_weapon(id, parent_path, position, velocity, weapon_id, ammo, drop_name):
	var destination = get_node_or_null(parent_path)
	if destination == null or destination.has_node(NodePath(drop_name)):
		return
	var drop = preload("res://Entities/Objects/Gun_Pickup.tscn").instance()
	drop.name = drop_name
	destination.add_child(drop)
	drop.global_transform.origin = position
	drop.gun.MESH[drop.gun.current_weapon].hide()
	drop.gun.current_weapon = weapon_id
	drop.gun.ammo = ammo
	drop.velocity = velocity
	drop.gun.MESH[weapon_id].show()
	drop.playerIgnoreId = id

puppet func sync_player_life(id, peer_id, is_dead):
	if typeof(peer_id) != TYPE_INT or typeof(is_dead) != TYPE_BOOL or not players.has(peer_id):
		return
	if is_dead:
		if not died_players.has(peer_id):
			died_players.append(peer_id)
	else:
		died_players.erase(peer_id)
		team_wipe_applied = false
	var puppet = players[peer_id].get("puppet")
	if not is_instance_valid(puppet):
		return
	if is_dead:
		if not puppet.death:
			puppet.play_explosion_sound()
		puppet._set_death(null, true)
	else:
		puppet.player_restart()

puppet func apply_team_wipe(id):
	if team_wipe_applied:
		return
	team_wipe_applied = true
	DeathScreen.apply_team_wipe()

puppet func set_death_label(id):
	DeathScreen.set_death_label()

func restart_map():
	if is_instance_valid(Flow) and Flow.result_active:
		Flow.restart_mission()
		return
	hide_death_screen(null)
	NetworkBridge.n_rpc(self, "hide_death_screen")
	goto_scene_host(hostSettings.map)

puppet func hide_death_screen(id):
	DeathScreen.hide()
	if playerPuppet != null:
		playerPuppet.respawn_puppet(null)

func player_respawn():
	if NetworkBridge.check_connection() and NetworkBridge.n_is_network_master(self):
		_player_respawn(null, true)
	else:
		NetworkBridge.n_rpc(self, "_player_respawn")

master func _player_respawn(id, host = false):
	if not NetworkBridge.is_world_authority():
		return
	id = NetworkBridge.request_sender(id)
	if players.has(id):
		died_players.erase(id)
		team_wipe_applied = false
		sync_player_life(null, id, false)
		NetworkBridge.n_rpc(self, "sync_player_life", [id, false])
		$RestartTimer.stop()



func enable_menu():
	Global.menu.multiplayer_exit()
	Global.menu.set_process_input(true)
	Menu.set_process_input(false)

func disable_menu():
	if not NetworkBridge.check_connection():
		return
	Global.menu.multiplayer_enter()
	Global.menu.set_process_input(false)
	Menu.set_process_input(true)



func game_init(level) -> bool:
	if not NetworkBridge.check_connection():
		_announce_difficulty = false
		player_scene_loaded = true
		Menu.hide()
		Menu.set_process_input(false)
		$SyncLoad.hide()
		Global.menu.set_process_input(true)
		Global.goto_scene(level)
		return true
	
	if NetworkBridge.n_is_network_master(self):
		goto_scene_host(level)
		return true
	return false

func get_menu_scene():
	if NetworkBridge.check_connection():
		return "res://MOD_CONTENT/CruS Online/maps/crus_online_lobby.tscn"
	return "res://Menu/Main_Menu.tscn"

func _update_menu_background():
	if Global.menu.in_game or Global.loader != null or not is_instance_valid(Global.current_scene):
		return
	if Global.current_scene.is_queued_for_deletion():
		return
	var current = Global.current_scene.filename
	if current in ["res://Menu/Main_Menu.tscn", "res://MOD_CONTENT/CruS Online/maps/crus_online_lobby.tscn"] and current != get_menu_scene():
		Global.goto_scene(get_menu_scene())

master func request_menu_exit(id, level_select):
	if not NetworkBridge.check_connection() or not NetworkBridge.is_world_authority():
		return
	if typeof(level_select) != TYPE_BOOL or not players.has(NetworkBridge.request_sender(id)) or not Global.menu.in_game:
		return
	if NetworkBridge.request_sender(id) == NetworkBridge.get_host_id():
		goto_menu_host(false, level_select)
	else:
		Flow.request_wait(id, level_select)

func _prepare_menu_return(level_select):
	_menu_destination = "level_select" if level_select else "main"
	player_scene_loaded = true
	loaded_players.clear()
	if is_connected("host_tick", self, "check_players_load"):
		disconnect("host_tick", self, "check_players_load")
	$SyncLoad.hide()
	Menu.hide()
	Menu.set_process_input(false)
	Hint.hide()

func host_session_ended():
	if players.empty() and not dataLoaded and not SteamLobby.in_lobby():
		return
	leave_server()
	_prepare_menu_return(false)
	Global.cutscene = false
	Global.border.show()
	Players.remove_players()
	Global.menu.in_game = false
	Global.goto_scene(get_menu_scene())
	emit_signal("disconnected_from_server", errorType.SERVER_CLOSED)

puppet func reward_npc_kill(id):
	if is_instance_valid(Global.player) and not Global.player.died and Global.implants.arm_implant.cursed_torch and Global.player.health < 100:
		Global.player.health += 1
		Global.player.UI.set_health(Global.player.health)

var _actors_frame = -1
var _alive_actors = []

func get_alive_actors():
	var frame = Engine.get_physics_frames()
	if frame != _actors_frame:
		_actors_frame = frame
		_alive_actors.clear()
		var local_id = NetworkBridge.get_id()
		for actor in get_tree().get_nodes_in_group("Player"):
			if preload("res://MOD_CONTENT/CruS Online/EnemyTargeting.gd").alive(actor, Global.player, local_id, died_players):
				_alive_actors.append(actor)
	return _alive_actors

func refresh_local_profile():
	var peer = NetworkBridge.get_id()
	if not NetworkBridge.check_connection() or not players.has(peer):
		return
	if NetworkBridge.is_world_authority():
		for field in ["nickname", "color", "image", "skinPath"]:
			players[peer][field] = playerInfo[field]
		Players.sync_players()
		emit_signal("players_update", players)
		NetworkBridge.n_rpc(self, "sync_players", [_public_players()])
