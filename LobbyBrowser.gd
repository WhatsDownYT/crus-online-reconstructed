extends PanelContainer

onready var main_tab = get_parent()
onready var Multiplayer = Global.get_node("Multiplayer")
onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")
onready var SteamLobby = Global.get_node("Multiplayer/SteamInit/SteamLobby")
onready var SteamInit = Global.get_node("Multiplayer/SteamInit")
onready var SteamNetwork = Global.get_node("Multiplayer/SteamInit/SteamNetwork")
onready var playersList = $VBoxContainer/PlayersList/PlayersListLabel
onready var LobbyList = $VBoxContainer/PlayersList/LobbyList
onready var LobbyInfo = $VBoxContainer/LobbyInfo
onready var LobbyPlayers = $VBoxContainer/LobbyInfo/PlayersInfo
onready var LobbyCode = $VBoxContainer/LobbyInfo/CodeInfo
onready var status = $VBoxContainer/Status/StatusLabel

var lobbies = []
var selected_lobby = 0
var code_visible = false
var connecting = false
var code_search = false

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	SteamLobby.connect("lobby_list", self, "_on_match_list")
	SteamLobby.connect("lobby_code_result", self, "_on_code_result")
	SteamLobby.connect("lobby_creation_failed", self, "_creation_failed")
	for signal_name in ["player_joined_lobby", "player_left_lobby", "lobby_joined"]:
		SteamLobby.connect(signal_name, self, "player_list_update")
	SteamLobby.connect("lobby_join_requested", self, "lobby_join_requested")
	Multiplayer.connect("status_update", self, "update_status")
	$"%LobbyCodeInput".connect("code_entered", self, "_direct_join")
	SteamNetwork.register_rpcs(self, [["_rpc_client", SteamNetwork.PERMISSION.SERVER], ["_rpc_server", SteamNetwork.PERMISSION.CLIENT_ALL]])
	$VBoxContainer/Buttons/Join.disabled = true
	$VBoxContainer/Status.hide()
	LobbyInfo.hide()
	LobbyCode.mouse_filter = Control.MOUSE_FILTER_STOP
	LobbyCode.connect("gui_input", self, "_code_input")
	LobbyCode.connect("mouse_entered", self, "_code_hover", [true])
	LobbyCode.connect("mouse_exited", self, "_code_hover", [false])
	LobbyCode.hint_tooltip = "Click to show or hide the code"
	LobbyCode.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func create_lobby():
	connecting = true
	SteamLobby.create_lobby(2 if Multiplayer.config.get("hostLobbyType", "public") == "public" else 3, 16)
	_show_connecting("Creating lobby...")

func lobby_join_requested(id, code = ""):
	NetworkBridge.set_mode(NetworkBridge.MULTIPLAYER_TYPE.STEAM)
	connect_lobby(int(id), code)

func join_lobby():
	if selected_lobby != 0:
		connect_lobby(selected_lobby)

func connect_lobby(lobby_id, code = ""):
	if lobby_id <= 0 or connecting:
		return
	connecting = true
	SteamLobby.join_lobby(lobby_id, code)
	_show_connecting("Connecting...")

func _show_connecting(message):
	for name in ["Create", "Join", "DirectJoin", "Refresh"]:
		$VBoxContainer/Buttons.get_node(name).hide()
	$VBoxContainer/Buttons/Leave.show()
	status.text = message
	$VBoxContainer/Status.show()
	playersList.hide()
	LobbyList.show()
	LobbyInfo.hide()

func leave_lobby():
	connecting = false
	code_search = false
	code_visible = false
	Multiplayer.leave_server()
	Multiplayer.emit_signal("status_update", "Offline")
	$VBoxContainer/Buttons/Create.show()
	$VBoxContainer/Buttons/Join.show()
	$VBoxContainer/Buttons/Join.disabled = true
	$VBoxContainer/Buttons/DirectJoin.show()
	$VBoxContainer/Buttons/Refresh.show()
	$VBoxContainer/Buttons/Leave.hide()
	selected_lobby = 0
	playersList.hide()
	$VBoxContainer/Status.hide()
	LobbyList.show()
	LobbyInfo.hide()

func lobby_selected(lobby_id):
	selected_lobby = lobby_id
	$VBoxContainer/Buttons/Join.disabled = lobby_id == 0
	for row in LobbyList.get_node("Rows").get_children():
		row.modulate = Color(1, 0.4, 0.4) if int(row.get_meta("lobby_id")) == lobby_id else Color(1, 1, 1)

func get_lobbies():
	SteamLobby.request_lobby_list()

func _creation_failed():
	connecting = false
	$VBoxContainer/Buttons/Create.show()
	$VBoxContainer/Buttons/Join.show()
	$VBoxContainer/Buttons/DirectJoin.show()
	$VBoxContainer/Buttons/Refresh.show()
	$VBoxContainer/Buttons/Leave.hide()
	playersList.hide()
	LobbyList.show()
	status.text = "Could not create lobby"

func direct_join():
	$"%LobbyCodeInput".open()

func _direct_join(code):
	if connecting or code_search:
		return
	code_search = SteamLobby.request_lobby_list(code)
	if code_search:
		status.text = "Finding lobby..."
		$VBoxContainer/Status.show()

func _on_code_result(lobby_id):
	code_search = false
	if lobby_id == 0:
		status.text = "Lobby unavailable or code not found"
		$VBoxContainer/Status.show()
		return
	connect_lobby(lobby_id, $"%LobbyCodeInput".entered_code)

func _on_match_list(received_lobbies):
	if connecting or SteamLobby.in_lobby():
		return
	var rows = LobbyList.get_node("Rows")
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	lobbies.clear()
	var selected_found = false
	for lobby_id in received_lobbies:
		if not SteamLobby.is_compatible_lobby(lobby_id) or SteamInit.Steam.getLobbyData(lobby_id, "lobby_type") != "public":
			continue
		lobbies.append(lobby_id)
		selected_found = selected_found or selected_lobby == lobby_id
		var lobby_name = SteamInit.Steam.getLobbyData(lobby_id, "name")
		if lobby_name.empty() or lobby_name.to_lower() == "null":
			lobby_name = SteamInit.Steam.getFriendPersonaName(SteamInit.Steam.getLobbyOwner(lobby_id)) + "'s lobby"
		var mode = SteamInit.Steam.getLobbyData(lobby_id, "mode")
		match mode:
			"deathmatch": mode = "Deathmatch"
			"counter_op": mode = "Counter-Opps"
			_: mode = "Cruelty"
		var count_text = "%d / %d players" % [SteamInit.Steam.getNumLobbyMembers(lobby_id), SteamInit.Steam.getLobbyMemberLimit(lobby_id)]
		var ping = SteamLobby.lobby_ping_ms(lobby_id)
		var ping_text = "%d ms est." % ping if ping >= 0 else "-- ms"
		_add_row(rows, lobby_id, lobby_name, mode, count_text, ping_text)
	if not selected_found:
		selected_lobby = 0
	lobby_selected(selected_lobby)

func _add_row(rows, lobby_id, lobby_name, mode, count_text, ping_text):
	var row = Button.new()
	row.rect_min_size = Vector2(0, 58)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("lobby_id", lobby_id)
	row.hint_tooltip = lobby_name
	row.connect("pressed", self, "lobby_selected", [lobby_id])
	row.connect("gui_input", self, "_row_input", [lobby_id])
	rows.add_child(row)
	var columns = HBoxContainer.new()
	columns.anchor_right = 1.0
	columns.anchor_bottom = 1.0
	columns.margin_left = 10
	columns.margin_right = -10
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(columns)
	for values in [[lobby_name, count_text], [mode, ping_text]]:
		var stack = VBoxContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		columns.add_child(stack)
		for value in values:
			var label = Label.new()
			label.text = value
			label.clip_text = true
			label.align = Label.ALIGN_RIGHT if values[0] == mode else Label.ALIGN_LEFT
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack.add_child(label)

func _row_input(event, lobby_id):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed and event.doubleclick:
		connect_lobby(lobby_id)

func player_list_update(_value):
	var players = SteamLobby.get_lobby_members()
	playersList.bbcode_text = ""
	var number = 1
	for player in players:
		playersList.bbcode_text += str(number) + ": " + players[player]
		playersList.bbcode_text += " (host)\n" if SteamLobby.is_owner(player) else "\n"
		number += 1
	_refresh_lobby_info()

func _refresh_lobby_info():
	if not SteamLobby.in_lobby():
		LobbyInfo.hide()
		return
	var id = SteamLobby.get_lobby_id()
	LobbyPlayers.text = "Players: %d / %d" % [SteamInit.Steam.getNumLobbyMembers(id), SteamInit.Steam.getLobbyMemberLimit(id)]
	LobbyCode.text = "Code: %s" % (SteamLobby.lobby_code() if code_visible else "******")
	LobbyInfo.show()

func _code_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed and SteamLobby.in_lobby():
		code_visible = not code_visible
		_refresh_lobby_info()

func _code_hover(over):
	LobbyCode.modulate = Color(1, 0.2, 0.2) if over else Color(1, 1, 1)

func back_to_menu():
	main_tab.current_tab = 0
	leave_lobby()

func update_status(new_status):
	status.text = new_status
	if new_status == "Offline":
		connecting = false
		$VBoxContainer/Buttons/Create.show()
		$VBoxContainer/Buttons/Join.show()
		$VBoxContainer/Buttons/DirectJoin.show()
		$VBoxContainer/Buttons/Refresh.show()
		$VBoxContainer/Buttons/Leave.hide()
		playersList.hide()
		LobbyList.show()
		$VBoxContainer/Status.hide()
		LobbyInfo.hide()
		return
	$VBoxContainer/Status.show()
	if new_status in ["Connected to Lobby", "Lobby owner"] and SteamLobby.in_lobby():
		connecting = false
		_refresh_lobby_info()
		playersList.show()
		LobbyList.hide()
		for name in ["Create", "Join", "DirectJoin", "Refresh"]:
			$VBoxContainer/Buttons.get_node(name).hide()
		$VBoxContainer/Buttons/Leave.show()
		main_tab.current_tab = 2

func _rpc_test():
	if NetworkBridge.check_connection():
		if NetworkBridge.r_is_network_master(self):
			NetworkBridge.r_rpc(self, "_rpc_client")
		else:
			NetworkBridge.r_rpc(self, "_rpc_server")

master func _rpc_server(id):
	pass

puppet func _rpc_client(id):
	pass
