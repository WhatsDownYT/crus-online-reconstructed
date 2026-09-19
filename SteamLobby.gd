extends Node

signal player_joined_lobby(steam_id)
signal player_left_lobby(steam_id)
signal lobby_created(lobby_id)
signal lobby_joined(lobby_id)
signal lobby_join_requested(lobby_id)
signal lobby_owner_changed(previous_owner, new_owner)
signal lobby_data_updated(steam_id)
signal chat_message_received(sender_steam_id, message)

signal lobby_list(lobbies)

var _my_steam_id := 0
var _steam_lobby_id := 0
var _steam_lobby_host := 0
var _members = {}

var _creating_lobby = false
var _pending_lobby_id = 0

onready var Multiplayer = Global.get_node("Multiplayer")

onready var SteamInit = get_parent()

enum CHAT_UPDATE {CHAT_MEMBER_STATE_CHANGE_ENTERED = 1, CHAT_MEMBER_STATE_CHANGE_LEFT = 2, CHAT_MEMBER_STATE_CHANGE_DISCONNECTED = 4, CHAT_MEMBER_STATE_CHANGE_KICKED = 8, CHAT_MEMBER_STATE_CHANGE_BANNED = 16}

func lobby_init():
	_my_steam_id = SteamInit.steam_id
	
	if _my_steam_id == 0:
		push_warning("Unable to get steam id of user, check steam has been initialized first.")
		return
	
	SteamInit.Steam.connect("lobby_created", self, "_on_lobby_created")
	SteamInit.Steam.connect("lobby_match_list", self, "_on_match_list")
	SteamInit.Steam.connect("lobby_joined", self, "_on_lobby_joined")
	SteamInit.Steam.connect("lobby_chat_update", self, "_on_lobby_chat_update")
	SteamInit.Steam.connect("lobby_message", self, "_on_lobby_message")
	SteamInit.Steam.connect("lobby_data_update", self, "_on_lobby_data_update")
	SteamInit.Steam.connect("lobby_invite", self, "_on_lobby_invite")
	SteamInit.Steam.connect("join_requested", self, "_on_lobby_join_requested")
	

	check_command_line()
	
	$"../SteamNetwork".init_network()

func get_lobby_id():
	return _steam_lobby_id

func in_lobby() -> bool:
	return not _steam_lobby_id == 0

func is_owner(steam_id = -1) -> bool:
	if get_lobby_owner() == null: return false
	if steam_id > 0:
		return get_lobby_owner() == steam_id
	return get_lobby_owner() == _my_steam_id

func get_lobby_owner():
	return SteamInit.Steam.getLobbyOwner(_steam_lobby_id)

func create_lobby(lobby_type: int, max_players: int):
	if _creating_lobby:
		return
	_creating_lobby = true
	if _steam_lobby_id == 0:
		print("Trying to create lobby of type %s" % lobby_type)
		SteamInit.Steam.createLobby(lobby_type, max_players)

func join_lobby(lobby_id: int):
	if lobby_id == _pending_lobby_id or lobby_id == _steam_lobby_id:
		return
	if in_lobby():
		Multiplayer.leave_server()
	_pending_lobby_id = lobby_id
	print("Trying to join lobby %s" % lobby_id)
	_members.clear()
	SteamInit.Steam.joinLobby(lobby_id)

func leave_lobby():
	var old_lobby = _steam_lobby_id
	_steam_lobby_id = 0
	_steam_lobby_host = 0
	_pending_lobby_id = 0
	_creating_lobby = false
	if old_lobby != 0:
		print("Leaving Lobby %s" % old_lobby)
		SteamInit.Steam.leaveLobby(old_lobby)
	for steam_id in _members:
		if steam_id != _my_steam_id:
			SteamInit.Steam.closeP2PSessionWithUser(steam_id)
	_members.clear()
	emit_signal("player_left_lobby", _my_steam_id)

func request_lobby_list():
	SteamInit.Steam.addRequestLobbyListDistanceFilter(SteamInit.Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)

	print("Requesting a lobby list")
	SteamInit.Steam.requestLobbyList()

func get_lobby_members() -> Dictionary:
	_update_lobby_members()
	return _members
	
func send_chat_message(message: String) -> bool:
	return SteamInit.Steam.sendLobbyChatMsg(_steam_lobby_id, message)

func _on_lobby_created(connect, lobby_id):
	print("Lobby Created called")
	_creating_lobby = false
	if connect == 1:
		_steam_lobby_id = lobby_id
		print("Created Steam Lobby with id: %s" % lobby_id)
		
		SteamInit.Steam.setLobbyJoinable(lobby_id, true)
		
		SteamInit.Steam.setLobbyData(lobby_id, "crus_online", true)
		SteamInit.Steam.setLobbyData(lobby_id, "version", network_version())
		
		if  Multiplayer.config.hostPassword == "":
			SteamInit.Steam.setLobbyData(lobby_id, "password", "False")
		else:
			SteamInit.Steam.setLobbyData(lobby_id, "password", "True")
		
		SteamInit.Steam.setLobbyData(lobby_id, "name", SteamInit.steam_username + "'s lobby")

		var relay = SteamInit.Steam.allowP2PPacketRelay(true)
		print("Relay configuration response: %s" % relay)
		
		emit_signal("lobby_created", lobby_id)
	else:
		push_error("Failed to create lobby: %s" % connect)

func _on_lobby_joined(lobby_id: int, permissions, locked: bool, response):
	if lobby_id != _pending_lobby_id and lobby_id != _steam_lobby_id and not _creating_lobby:
		SteamInit.Steam.leaveLobby(lobby_id)
		return
	if response != 1:
		_pending_lobby_id = 0
		Multiplayer.clear_connection(Multiplayer.errorType.SERVER_CLOSED)
		return
	_pending_lobby_id = 0
	print("Lobby Joined!")
	_steam_lobby_id = lobby_id
	_update_lobby_members()
	var remote_version = SteamInit.Steam.getLobbyData(lobby_id, "version")
	if get_lobby_owner() != _my_steam_id and remote_version != "" and remote_version != network_version():
		Multiplayer.clear_connection(Multiplayer.errorType.WRONG_VERSION)
		return
	emit_signal("lobby_joined", lobby_id)

func _on_lobby_join_requested(lobby_id: int, friend_id):
	print("Attempting to join lobby %s from request" % lobby_id)

	emit_signal("lobby_join_requested", lobby_id)
	
func _update_lobby_members():

	_members.clear()
	if not in_lobby():
		return

	_steam_lobby_host = SteamInit.Steam.getLobbyOwner(_steam_lobby_id)


	var num_members: int = SteamInit.Steam.getNumLobbyMembers(_steam_lobby_id)


	for member_index in range(0, num_members):


		var member_steam_id = SteamInit.Steam.getLobbyMemberByIndex(_steam_lobby_id, member_index)


		var member_steam_name = SteamInit.Steam.getFriendPersonaName(member_steam_id)


		_members[member_steam_id] = member_steam_name
	
	print(_members)
	
func _on_lobby_invite(inviter, lobby, game):
	pass
	
func _on_lobby_data_update(success, lobby_id, member_id):
	if lobby_id != _steam_lobby_id or not in_lobby():
		return
	if success:

		var host = SteamInit.Steam.getLobbyOwner(_steam_lobby_id)
		if host != _steam_lobby_host and host > 0:
			_owner_changed(_steam_lobby_host, host)
			_steam_lobby_host = host
		emit_signal("lobby_data_updated", member_id)
		
	print("Lobby Updated %s %s %s" % [success, lobby_id, member_id])

func _owner_changed(was_steam_id, now_steam_id):
	emit_signal("lobby_owner_changed", was_steam_id, now_steam_id)

func _on_lobby_message(result, sender_steam_id, message, chat_type):
	if result == 0:
		push_error("Received lobby message, but 0 bytes were retrieved!")
	match(chat_type):
		SteamInit.Steam.CHAT_ENTRY_TYPE_CHAT_MSG:
			if not _members.has(sender_steam_id):
				push_error("Received a message from a user we dont have locally!")
			var profile_name = _members[sender_steam_id]
			emit_signal("chat_message_received", sender_steam_id, profile_name, message)
		_:
			push_warning("Unhandled chat message type received: %s" % chat_type)

func _on_lobby_chat_update(lobby_id, changed_user_steam_id, user_made_change_steam_id, chat_state):
	if lobby_id != _steam_lobby_id or not in_lobby():
		return
	match chat_state:
		CHAT_UPDATE.CHAT_MEMBER_STATE_CHANGE_ENTERED:
			print("Player joined lobby %s" % changed_user_steam_id)
			emit_signal("player_joined_lobby", changed_user_steam_id)
		CHAT_UPDATE.CHAT_MEMBER_STATE_CHANGE_LEFT:
			print("Player left the lobby %s" % changed_user_steam_id)
			emit_signal("player_left_lobby", changed_user_steam_id)
		CHAT_UPDATE.CHAT_MEMBER_STATE_CHANGE_KICKED:
			print("Player %s was kicked by %s" % [changed_user_steam_id, user_made_change_steam_id])
			emit_signal("player_left_lobby", changed_user_steam_id)
		CHAT_UPDATE.CHAT_MEMBER_STATE_CHANGE_BANNED:
			print("Player %s was banned by %s" % [changed_user_steam_id, user_made_change_steam_id])
			emit_signal("player_left_lobby", changed_user_steam_id)
		CHAT_UPDATE.CHAT_MEMBER_STATE_CHANGE_DISCONNECTED:
			print("Player disconnected %s" % changed_user_steam_id)
			emit_signal("player_left_lobby", changed_user_steam_id)

func _on_match_list(lobbies, count):
	emit_signal("lobby_list", lobbies)

func check_command_line():
	var args = OS.get_cmdline_args()
	
	print("[CRUS ONLINE / STEAM LOBBY]: Check command line")


	if args.size() > 0:
		var _lobby_invite_arg := false

		for arg in args:
			print("Command line: "+str(arg))


			if _lobby_invite_arg:
				print("[CRUS ONLINE / STEAM LOBBY]: Lobby join requested")
				emit_signal("lobby_join_requested", int(arg))



			if arg == "+connect_lobby":
				_lobby_invite_arg = true

func _exit_tree():
	leave_lobby()

func network_version():
	return Multiplayer.version + "-net" + str(get_node("../SteamNetwork").PROTOCOL_VERSION)
