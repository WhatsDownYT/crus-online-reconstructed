extends Node

onready var Multiplayer = get_parent()
onready var NetworkBridge = get_parent().get_node("NetworkBridge")
var result_active = false
var result_won = false
var result_level = 0
var waiting_peers = []
var world = {}
var personal_difficulty = {}
var misery_transition = false
var finishing = false
var used_orbs = {}

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	NetworkBridge.register_rpcs(self, [["sync_difficulty", NetworkBridge.PERMISSION.SERVER], ["request_orb", NetworkBridge.PERMISSION.ALL], ["apply_orb", NetworkBridge.PERMISSION.SERVER], ["configure_world", NetworkBridge.PERMISSION.SERVER], ["show_result", NetworkBridge.PERMISSION.SERVER], ["request_wait", NetworkBridge.PERMISSION.ALL], ["sync_waiting", NetworkBridge.PERMISSION.SERVER]])

func difficulty():
	return {"soul_intact": Global.soul_intact, "husk_mode": Global.husk_mode, "hope_discarded": Global.hope_discarded, "hell_discovered": Global.hell_discovered, "punishment_mode": Global.punishment_mode, "chaos_mode": Global.chaos_mode, "consecutive_deaths": Global.consecutive_deaths}

func set_difficulty(state):
	for key in state:
		if difficulty().has(key):
			Global.set(key, state[key])
	var index = 3 if Global.hope_discarded else (2 if Global.husk_mode else (1 if Global.soul_intact else 0))
	Global.border.texture = Global.BORDERS[index]
	_update_local_effects()

func prepare_mission():
	clear_result()
	used_orbs.clear()
	waiting_peers.clear()
	world = {"rain": rand_range(0, 100) > 90 or Global.implants.head_implant.fishing_bonus, "hour": OS.get_time().hour, "share": Multiplayer.hostSettings.get("shareDifficulty", false), "difficulty": difficulty(), "ending_2": Global.ending_2}
	configure_world(null, world)
	NetworkBridge.n_rpc(self, "configure_world", [world])

puppet func configure_world(id, state):
	world = state.duplicate(true)
	waiting_peers.clear()
	Global.rain = world.get("rain", false)
	if world.share:
		if not NetworkBridge.is_world_authority() and personal_difficulty.empty():
			personal_difficulty = difficulty()
		set_difficulty(world.difficulty)
	elif not personal_difficulty.empty():
		set_difficulty(personal_difficulty)
		personal_difficulty.clear()

func clear_result():
	result_active = false
	finishing = false
	misery_transition = false
	get_tree().paused = false
	Multiplayer.DeathScreen.hide()
	Global.menu.get_node("Level_End_Grid").hide()
	Global.menu.get_node("Soul_Rended").hide()
	Global.menu.active_element = null
	if is_instance_valid(Global.player):
		Global.player.set_process_input(true)
		Global.player.set_physics_process(true)
		Global.player.set_process(true)

func reset_session():
	clear_result()
	waiting_peers.clear()
	world.clear()
	if not personal_difficulty.empty():
		set_difficulty(personal_difficulty)
		personal_difficulty.clear()
		Global.save_game()

func ending_path():
	if Global.CURRENT_LEVEL == Global.L_PUNISHMENT:
		return "res://Cutscenes/CutsceneEnd1.tscn"
	if Global.CURRENT_LEVEL == Global.L_HQ:
		return "res://Cutscenes/CutsceneEnd2.tscn"
	if Global.CURRENT_LEVEL == 18:
		return "res://Cutscenes/CutsceneEnd3.tscn"
	return ""

func check_team_wipe():
	if not NetworkBridge.is_world_authority() or not Global.menu.in_game or result_active or finishing:
		return
	var participants = 0
	for peer in Multiplayer.players:
		if waiting_peers.has(peer):
			continue
		participants += 1
		if not Multiplayer.died_players.has(peer):
			return
	if participants > 0:
		call_deferred("finish_mission", false)

func lower_difficulty():
	var previous = difficulty()
	if Multiplayer.hostSettings.changeModeOnDeath and not Global.hope_discarded and not Global.husk_mode:
		Global.consecutive_deaths += 1
		Global.soul_intact = false
		if Global.consecutive_deaths >= 4:
			Global.husk_mode = true
			Global.money = max(Global.money, 0)
	set_difficulty(difficulty())
	return "misery" if not previous.husk_mode and Global.husk_mode else ("severed" if previous.soul_intact and not Global.soul_intact else "")

func finish_mission(won):
	if not NetworkBridge.is_world_authority() or result_active or finishing:
		return
	finishing = true
	var loss = ""
	if won:
		Global.record_multiplayer_win()
	else:
		loss = lower_difficulty()
	var state = {"won": won, "level": Global.CURRENT_LEVEL, "enemy_count": Global.enemy_count, "enemy_count_total": Global.enemy_count_total, "civ_count": Global.civ_count, "civ_count_total": Global.civ_count_total, "level_time": Global.level_time, "level_time_raw": Global.level_time_raw, "difficulty": difficulty(), "loss": loss, "ending": ending_path() if won else "", "epoch": Multiplayer.SteamNetwork.scene_epoch + 1}
	NetworkBridge.n_rpc(self, "show_result", [state])
	show_result(null, state)

puppet func show_result(id, state):
	if result_active or (waiting_peers.has(NetworkBridge.get_id()) and state.ending == ""):
		return
	result_active = true
	finishing = false
	result_won = state.won
	result_level = state.level
	Multiplayer.get_node("RestartTimer").stop()
	Global.CURRENT_LEVEL = state.level
	for key in ["enemy_count", "enemy_count_total", "civ_count", "civ_count_total", "level_time", "level_time_raw"]:
		Global.set(key, state[key])
	var shared = Multiplayer.hostSettings.get("shareDifficulty", false)
	if shared:
		set_difficulty(state.difficulty)
	elif not state.won and not NetworkBridge.is_world_authority():
		lower_difficulty()
	misery_transition = shared and state.loss == "misery"
	if misery_transition:
		Global.money = max(Global.money, 0)
	if state.won:
		if not NetworkBridge.is_world_authority():
			Global.record_multiplayer_win()
			if shared:
				set_difficulty(state.difficulty)
		if state.ending != "":
			Global.ending_1 = Global.ending_1 or state.ending.ends_with("End1.tscn")
			Global.ending_2 = Global.ending_2 or state.ending.ends_with("End2.tscn")
			Global.ending_3 = Global.ending_3 or state.ending.ends_with("End3.tscn")
	else:
		if not Global.husk_mode:
			Global.money -= 500
	if state.ending.ends_with("End2.tscn"):
		Global.character_mat.set_shader_param("albedoTex", load("res://Textures/NPC/bosssguy_clothes.png"))
	Global.save_game()
	Multiplayer.DeathScreen.hide()
	Multiplayer.Menu.hide()
	Multiplayer.Menu.set_process_input(false)
	for online_menu in get_tree().get_nodes_in_group("MultiplayerMenu"):
		online_menu.disable_menu()
	if state.ending != "":
		get_tree().paused = false
		Multiplayer._menu_destination = ""
		Multiplayer.player_scene_loaded = true
		Multiplayer.SteamNetwork.begin_scene(state.epoch)
		Multiplayer.get_node("CancerReplication").reset(state.epoch)
		Global.menu.in_game = false
		Global.menu.hide()
		Multiplayer.Players.remove_players()
		Global.goto_scene(state.ending)
		return
	Global.player.set_process_input(false)
	Global.player.set_process(false)
	Global.player.set_physics_process(false)
	Global.player.weapon.disabled = true
	Global.UI.hide()
	get_tree().paused = true
	Global.menu.in_game = true
	Global.menu.set_process_input(true)
	Global.menu.get_node("Level_End_Grid").active = true
	Global.menu.level_end()
	Global.menu.get_node("Level_End_Grid").rect_size.x = 720
	Global.menu.get_node("Level_End_Grid/Performance_Hbox/Performance_Scroll/Performance_Vbox/Time_Label").text = "Time:" + Global.level_time
	Global.menu.show()
	var popup = Global.menu.get_node("Soul_Rended")
	popup.hide()
	if not state.won and shared and state.loss != "":
		popup.texture = load("res://Textures/Menu/Misery_Achieved.png" if misery_transition else "res://Textures/Menu/Soul_Rended.png")
		popup.rect_position = Vector2(64, 128)
		popup.rect_size = Vector2(420, 420)
		popup.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func restart_mission():
	if NetworkBridge.is_world_authority():
		Global.CURRENT_LEVEL = result_level if result_active else Global.CURRENT_LEVEL
		Multiplayer.game_init(Global.LEVELS[Global.CURRENT_LEVEL])

func exit_to_menu(level_select):
	if NetworkBridge.is_world_authority():
		if level_select and result_active and result_won and result_level < Global.L_PUNISHMENT and result_level != Global.L_HQ:
			Global.CURRENT_LEVEL = result_level + 1
		Multiplayer.goto_menu_host(false, level_select)
	else:
		NetworkBridge.request_host(self, "request_wait", [level_select])

master func request_wait(id, level_select):
	id = NetworkBridge.request_sender(id)
	if not NetworkBridge.is_world_authority() or not Multiplayer.players.has(id) or id == NetworkBridge.get_host_id() or typeof(level_select) != TYPE_BOOL:
		return
	NetworkBridge.n_rpc(self, "sync_waiting", [id, level_select])
	sync_waiting(null, id, level_select)
	check_team_wipe()

puppet func sync_waiting(id, peer, level_select):
	if not waiting_peers.has(peer):
		waiting_peers.append(peer)
	var puppet = Multiplayer.players.get(peer, {}).get("puppet")
	if is_instance_valid(puppet):
		puppet.queue_free()
	if peer == NetworkBridge.get_id():
		clear_result()
		Multiplayer._prepare_menu_return(level_select)
		Multiplayer.enable_menu()
		Global.menu.in_game = false
		Global.goto_scene(Multiplayer.get_menu_scene())
		Multiplayer.Players.remove_players()

func waiting_world_target(peer, caller):
	if not waiting_peers.has(peer):
		return false
	var path = str(caller.get_path())
	return path.begins_with("/root/Level/") or path.begins_with(str(Multiplayer.Players.get_path()) + "/")

func _process(_delta):
	if not NetworkBridge.check_connection() or not NetworkBridge.is_world_authority():
		return
	var current = difficulty()
	var shared = Multiplayer.hostSettings.get("shareDifficulty", false)
	var changed = false
	var previous = world.get("difficulty", {})
	for key in current:
		if previous.get(key) != current[key]:
			changed = true
			break
	if changed or world.get("share", false) != shared or world.get("ending_2", false) != Global.ending_2:
		_update_local_effects()
		world["difficulty"] = current
		world["share"] = shared
		world["ending_2"] = Global.ending_2
		NetworkBridge.n_rpc(self, "sync_difficulty", [current, shared, Global.ending_2])

puppet func sync_difficulty(id, state, shared, ending_two):
	world["difficulty"] = state.duplicate(true)
	world["share"] = shared
	world["ending_2"] = ending_two
	if shared:
		if personal_difficulty.empty():
			personal_difficulty = difficulty()
		set_difficulty(state)
	elif not personal_difficulty.empty():
		set_difficulty(personal_difficulty)
		personal_difficulty.clear()

master func request_orb(id, path):
	id = NetworkBridge.request_sender(id)
	if not NetworkBridge.is_world_authority() or not Multiplayer.players.has(id) or used_orbs.has(path) or result_active:
		return
	var orb = get_node_or_null(path)
	var actor = NetworkBridge.get_peer_actor(id)
	if not is_instance_valid(orb) or not orb.has_method("consume_orb") or not is_instance_valid(actor) or Multiplayer.died_players.has(id):
		return
	if actor.global_transform.origin.distance_to(orb.global_transform.origin) > 5.0:
		return
	used_orbs[path] = true
	if orb.soul:
		Global.set_soul()
	else:
		Global.set_hope()
	var state = difficulty()
	world["difficulty"] = state
	NetworkBridge.n_rpc(self, "apply_orb", [path, orb.soul, state])
	apply_orb(null, path, orb.soul, state)

puppet func apply_orb(id, path, soul, state):
	if not NetworkBridge.is_world_authority():
		if soul:
			Global.set_soul()
		else:
			Global.set_hope()
	set_difficulty(state)
	world["difficulty"] = state.duplicate(true)
	Global.save_game()
	var orb = get_node_or_null(path)
	if is_instance_valid(orb) and orb.has_method("consume_orb"):
		orb.consume_orb()
	if not soul and Global.menu.in_game and is_instance_valid(Global.player) and not Global.player.died:
		Global.player.suicide()

func send_world(peer):
	var state = {"rain": world.get("rain", false), "hour": world.get("hour", OS.get_time().hour), "share": Multiplayer.hostSettings.get("shareDifficulty", false), "difficulty": difficulty(), "ending_2": Global.ending_2}
	NetworkBridge.n_rpc_id(self, peer, "configure_world", [state])

func _update_local_effects():
	if not Global.menu.in_game or not is_instance_valid(Global.player) or not Global.player.has_method("_implant_speed_bonus"):
		return
	Global.player.speed_bonus = Global.player._implant_speed_bonus()
	Global.player.set_move_speed()
	Global.music.pitch_scale = 0.75 if Global.hope_discarded else 1.0
