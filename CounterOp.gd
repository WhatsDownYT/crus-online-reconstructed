extends Node

const MODE_CRUELTY = "cruelty"
const MODE_COUNTER_OP = "counter_op"
const TEAM_OPERATIVES = "operative"
const TEAM_COUNTER_OPERATIVES = "counter_operative"

onready var Multiplayer = get_parent()
onready var NetworkBridge = get_parent().get_node("NetworkBridge")

var teams = {}
var ready = {}
var settings = {
	"enemyFriendlyFire": false,
	"neutralEnemies": false,
	"randomizeTeams": false,
	"overrideTeams": false
}
var menu_ref = null
var overlay = null
var ready_button = null
var ready_count = null
var team_button = null
var round_operatives = []

signal state_changed()

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	NetworkBridge.register_rpcs(self, [
		["request_team", NetworkBridge.PERMISSION.ALL],
		["request_ready", NetworkBridge.PERMISSION.ALL],
		["request_setting", NetworkBridge.PERMISSION.ALL],
		["sync_state", NetworkBridge.PERMISSION.SERVER]
	])

func is_active():
	return Multiplayer.hostSettings.get("gameMode", MODE_CRUELTY) == MODE_COUNTER_OP

func team_of(peer):
	return teams.get(int(peer), TEAM_OPERATIVES)

func is_operative(peer):
	return team_of(peer) == TEAM_OPERATIVES

func is_counter_operative(peer):
	return team_of(peer) == TEAM_COUNTER_OPERATIVES

func same_team(a, b):
	return team_of(a) == team_of(b)

func can_select_team(peer):
	return is_active() and teams.has(int(peer)) and not settings.randomizeTeams and not settings.overrideTeams

func host_can_assign_team():
	return is_active() and NetworkBridge.is_world_authority() and settings.overrideTeams and not settings.randomizeTeams and is_instance_valid(Global.menu) and not Global.menu.in_game

func can_player_damage(source, target, normal_friendly_fire):
	if Multiplayer.Deathmatch.is_active():
		return true
	if not is_active() or source <= 0 or target <= 0 or not Multiplayer.players.has(source) or not Multiplayer.players.has(target):
		return normal_friendly_fire or source <= 0 or target <= 0 or source == target
	if source == target:
		return true
	if not same_team(source, target):
		return true
	return normal_friendly_fire

func can_revive(source, target):
	if Multiplayer.Deathmatch.is_active():
		return false
	if not is_active():
		return true
	return Multiplayer.players.has(source) and Multiplayer.players.has(target) and same_team(source, target)

func should_show_player_indicator(viewer, target):
	if not is_active() or viewer == target:
		return true
	if not Multiplayer.players.has(viewer) or not Multiplayer.players.has(target):
		return true
	return same_team(viewer, target)

func npc_targets_peer(source, peer):
	if not is_active() or not is_counter_operative(peer):
		return true
	return npc_is_hostile(source)

func npc_targets_actor(source, actor):
	var peer = NetworkBridge.damage_target_id(actor)
	return peer <= 0 or npc_targets_peer(source, peer)

func npc_is_hostile(source):
	var node = source
	while is_instance_valid(node):
		if node.has_meta("counterop_hostile"):
			return bool(node.get_meta("counterop_hostile"))
		node = node.get_parent()
	return false

func find_npc_handler(node):
	var current = node
	while is_instance_valid(current):
		if "objective" in current and current.has_method("network_damage") and current.has_method("die"):
			return current
		current = current.get_parent()
	return null

func can_damage_npc(source, npc):
	if not is_active() or not Multiplayer.players.has(source) or not is_counter_operative(source):
		return true
	var handler = find_npc_handler(npc)
	if is_instance_valid(handler) and handler.get("civilian") and not handler.objective:
		return true
	if not settings.enemyFriendlyFire:
		return false
	if settings.neutralEnemies and is_instance_valid(npc):
		_mark_npc_hostile(npc)
	return true

func _mark_npc_hostile(npc):
	npc.set_meta("counterop_hostile", true)
	var node = npc.get_parent()
	while is_instance_valid(node):
		if node.has_meta("counterop_npc"):
			node.set_meta("counterop_hostile", true)
		node = node.get_parent()

func allow_npc_action(source, target):
	var npc = find_npc_handler(target)
	if npc == null:
		return true
	return can_damage_npc(source, npc)

func required_exit_players(absent):
	var result = []
	for peer in Multiplayer.players:
		if absent.has(peer):
			continue
		if not is_active() or is_operative(peer):
			result.append(peer)
	return result

func operative_participants(waiting = []):
	var result = []
	for peer in Multiplayer.players:
		if not waiting.has(peer) and is_operative(peer):
			result.append(peer)
	return result

func all_operatives_dead(waiting = []):
	if not is_active():
		return false
	var operatives = round_operatives if not round_operatives.empty() else operative_participants(waiting)
	if operatives.empty():
		return not Multiplayer.players.empty()
	for peer in operatives:
		if Multiplayer.players.has(peer) and not waiting.has(peer) and not Multiplayer.died_players.has(peer):
			return false
	return true

func host_player_joined(peer):
	if not NetworkBridge.is_world_authority():
		return
	peer = int(peer)
	ready[peer] = false
	if not teams.has(peer):
		teams[peer] = _default_team(peer)
	broadcast_state()

func host_player_left(peer):
	if not NetworkBridge.is_world_authority():
		return
	teams.erase(int(peer))
	ready.erase(int(peer))
	if Multiplayer.players.size() < 2 and is_instance_valid(Global.menu) and not Global.menu.in_game and Multiplayer.hostSettings.get("gameMode", MODE_CRUELTY) != MODE_CRUELTY:
		set_mode(MODE_CRUELTY)
	broadcast_state()

func _default_team(peer):
	if not is_active():
		return TEAM_OPERATIVES
	var operative_count = 0
	var counter_count = 0
	for key in teams:
		if teams[key] == TEAM_COUNTER_OPERATIVES:
			counter_count += 1
		else:
			operative_count += 1
	return TEAM_OPERATIVES if operative_count <= counter_count else TEAM_COUNTER_OPERATIVES

func ensure_players():
	if not NetworkBridge.is_world_authority():
		return
	var changed = false
	for peer in Multiplayer.players:
		if not teams.has(peer):
			teams[peer] = _default_team(peer)
			changed = true
		if not ready.has(peer):
			ready[peer] = false
			changed = true
	for peer in teams.keys():
		if not Multiplayer.players.has(peer):
			teams.erase(peer)
			ready.erase(peer)
			changed = true
	if changed:
		broadcast_state()

func set_local_team(team):
	if not (team in [TEAM_OPERATIVES, TEAM_COUNTER_OPERATIVES]) or not can_select_team(NetworkBridge.get_id()):
		return
	if NetworkBridge.is_world_authority():
		_set_team(NetworkBridge.get_id(), team)
	else:
		NetworkBridge.request_host(self, "request_team", [team])

master func request_team(id, team):
	if not NetworkBridge.is_world_authority() or not (team in [TEAM_OPERATIVES, TEAM_COUNTER_OPERATIVES]):
		return
	var peer = NetworkBridge.request_sender(id)
	if not can_select_team(peer):
		return
	_set_team(peer, team)

func host_toggle_team(peer):
	if not host_can_assign_team() or not teams.has(int(peer)):
		return
	var next = TEAM_COUNTER_OPERATIVES if team_of(peer) == TEAM_OPERATIVES else TEAM_OPERATIVES
	_set_team(int(peer), next)

func _set_team(peer, team):
	teams[int(peer)] = team
	ready[int(peer)] = false
	broadcast_state()

func set_ready(value):
	var peer = NetworkBridge.get_id()
	if peer == NetworkBridge.get_host_id() or not Multiplayer.players.has(peer):
		return
	if NetworkBridge.is_world_authority():
		_set_ready(peer, value)
	else:
		NetworkBridge.request_host(self, "request_ready", [value])

master func request_ready(id, value):
	if not NetworkBridge.is_world_authority() or typeof(value) != TYPE_BOOL:
		return
	var peer = NetworkBridge.request_sender(id)
	if peer == NetworkBridge.get_host_id() or not Multiplayer.players.has(peer):
		return
	_set_ready(peer, value)

func _set_ready(peer, value):
	ready[int(peer)] = bool(value)
	broadcast_state()

func ready_counts():
	var count = 0
	var total = 0
	var host = NetworkBridge.get_host_id()
	for peer in Multiplayer.players:
		if peer == host:
			continue
		total += 1
		if ready.get(peer, false):
			count += 1
	return [count, total]

func set_setting(key, value):
	if not NetworkBridge.is_world_authority() or not settings.has(key) or typeof(value) != TYPE_BOOL:
		return
	_apply_setting(key, value)
	broadcast_state()

master func request_setting(id, key, value):
	if not NetworkBridge.is_world_authority() or NetworkBridge.request_sender(id) != NetworkBridge.get_host_id():
		return
	if not settings.has(key) or typeof(value) != TYPE_BOOL:
		return
	_apply_setting(key, value)
	broadcast_state()

func _apply_setting(key, value):
	settings[key] = value
	if key == "enemyFriendlyFire" and not value:
		settings.neutralEnemies = false
	if key in ["randomizeTeams", "overrideTeams"]:
		for peer in ready:
			ready[peer] = false

func set_mode(mode):
	if not NetworkBridge.is_world_authority() or not (mode in [MODE_CRUELTY, MODE_COUNTER_OP, "deathmatch"]):
		return
	if mode != MODE_CRUELTY and Multiplayer.players.size() < 2:
		return
	if is_instance_valid(Global.menu) and Global.menu.in_game:
		return
	Multiplayer.hostSettings.gameMode = mode
	if mode == MODE_COUNTER_OP:
		ensure_players()
	else:
		for peer in ready:
			ready[peer] = false
	Multiplayer.apply_host_settings()
	broadcast_state()

func host_apply_mode(mode):
	if not NetworkBridge.is_world_authority() or not (mode in [MODE_CRUELTY, MODE_COUNTER_OP, "deathmatch"]):
		return
	set_mode(mode)

func prepare_round():
	if not NetworkBridge.is_world_authority():
		return
	ensure_players()
	if is_active() and settings.randomizeTeams:
		randomize_teams()
	round_operatives.clear()
	if is_active():
		for peer in Multiplayer.players:
			if is_operative(peer):
				round_operatives.append(peer)
	for peer in ready:
		ready[peer] = false
	broadcast_state()

func reset_session():
	teams.clear()
	ready.clear()
	round_operatives.clear()
	_update_overlay()

func randomize_teams():
	if not NetworkBridge.is_world_authority():
		return
	for peer in Multiplayer.players:
		teams[peer] = TEAM_OPERATIVES if randi() % 2 == 0 else TEAM_COUNTER_OPERATIVES

func sync_to_peer(peer):
	if NetworkBridge.is_world_authority():
		NetworkBridge.n_rpc_id(self, int(peer), "sync_state", [_state()])

func broadcast_state():
	if not NetworkBridge.is_world_authority():
		return
	var state = _state()
	NetworkBridge.n_rpc(self, "sync_state", [state])
	emit_signal("state_changed")
	_update_overlay()

func _state():
	return {"teams": teams.duplicate(true), "ready": ready.duplicate(true), "settings": settings.duplicate(true)}

puppet func sync_state(id, state):
	if typeof(state) != TYPE_DICTIONARY:
		return
	_apply_state(state)

func _apply_state(state):
	teams = state.get("teams", {}).duplicate(true)
	ready = state.get("ready", {}).duplicate(true)
	var incoming = state.get("settings", {})
	for key in settings:
		if incoming.has(key) and typeof(incoming[key]) == TYPE_BOOL:
			settings[key] = incoming[key]
	emit_signal("state_changed")
	_update_overlay()

func attach_menu(menu):
	menu_ref = menu
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = Control.new()
	overlay.name = "CounterOpOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.rect_size = Vector2(1280, 720)
	menu.add_child(overlay)
	ready_button = _make_square("Ready", "res://Textures/Menu/mission_start.png", Vector2(24, 624), "Tell the host that you are ready. The host can still start without everyone being ready.")
	ready_button.connect("pressed", self, "_ready_pressed")
	team_button = _make_square("", "res://MOD_CONTENT/CruS Online/target_white.png", Vector2(104, 624), "Switch between the Operatives and Counter-Operatives teams.")
	team_button.texture_hover = team_button.texture_normal
	team_button.texture_pressed = team_button.texture_normal
	team_button.get_node("Text").hide()
	team_button.connect("pressed", self, "_team_pressed")
	ready_count = Label.new()
	ready_count.rect_position = Vector2(184, 640)
	ready_count.rect_size = Vector2(320, 40)
	ready_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ready_count.add_font_override("font", _font(20))
	overlay.add_child(ready_count)
	_update_overlay()

func _font(size):
	var font = DynamicFont.new()
	font.font_data = load("res://Fonts/gamefont(1).ttf")
	font.size = size
	return font

func _make_square(label_text, texture_path, position, tooltip):
	var button = TextureButton.new()
	button.rect_position = position
	button.rect_size = Vector2(64, 64)
	button.expand = true
	button.texture_normal = load(texture_path)
	button.texture_hover = load("res://Textures/Menu/hover.png")
	button.connect("mouse_entered", self, "_tooltip_entered", [tooltip])
	button.connect("mouse_exited", self, "_tooltip_exited")
	var label = Label.new()
	label.name = "Text"
	label.text = label_text
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	label.rect_position = Vector2(-8, 66)
	label.rect_size = Vector2(80, 44)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_font_override("font", _font(14))
	button.add_child(label)
	overlay.add_child(button)
	return button

func _tooltip_entered(description):
	if not is_instance_valid(menu_ref) or not is_instance_valid(menu_ref.hover_info):
		return
	var hover = menu_ref.hover_info
	hover.get_node("Image").hide()
	hover.get_node("Name").hide()
	hover.get_node("Hint").show()
	hover.get_node("Hint").text = description
	hover.get_parent().rect_size = Vector2.ZERO
	hover.get_parent().raise()
	hover.get_parent().show()

func _tooltip_exited():
	if not is_instance_valid(menu_ref) or not is_instance_valid(menu_ref.hover_info):
		return
	menu_ref.hover_info.get_node("Name").show()
	menu_ref.hover_info.get_parent().hide()
	menu_ref.hover_info.get_parent().rect_size = Vector2.ZERO

func _level_select_open():
	if not is_instance_valid(menu_ref) or not NetworkBridge.check_connection() or menu_ref.in_game or menu_ref.active_menus.empty():
		return false
	return menu_ref.active_menus.back() == menu_ref.menu[menu_ref.LEVEL_SELECT]

func _process(_delta):
	if is_instance_valid(overlay):
		_update_overlay()

func _update_overlay():
	if not is_instance_valid(overlay):
		return
	var visible_now = _level_select_open()
	overlay.visible = visible_now
	if not visible_now:
		return
	var host = NetworkBridge.is_world_authority()
	var active = is_active()
	ready_button.visible = not host
	var local_ready = ready.get(NetworkBridge.get_id(), false)
	ready_button.modulate = Color(0.6, 1.0, 0.6) if local_ready else Color.white
	ready_button.get_node("Text").text = "Ready" if not local_ready else "Ready!"
	team_button.visible = active and can_select_team(NetworkBridge.get_id())
	if team_button.visible:
		_position_team_button()
		team_button.modulate = Color(0, 1, 0, 1) if is_operative(NetworkBridge.get_id()) else Color(1, 0, 0, 1)
	ready_count.visible = host
	var counts = ready_counts()
	ready_count.text = "Players ready: %d/%d" % [counts[0], counts[1]]

func _position_team_button():
	if not is_instance_valid(menu_ref) or menu_ref.menu.size() <= menu_ref.LEVEL_SELECT:
		return
	var level_menu = menu_ref.menu[menu_ref.LEVEL_SELECT]
	if level_menu.get_child_count() <= 2:
		return
	var stock_button = level_menu.get_child(2)
	team_button.rect_position = stock_button.rect_position + Vector2(64, 0)

func _ready_pressed():
	set_ready(not ready.get(NetworkBridge.get_id(), false))

func _team_pressed():
	var next = TEAM_COUNTER_OPERATIVES if team_of(NetworkBridge.get_id()) == TEAM_OPERATIVES else TEAM_OPERATIVES
	set_local_team(next)
