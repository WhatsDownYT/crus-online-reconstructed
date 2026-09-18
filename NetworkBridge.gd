extends Node

enum MULTIPLAYER_TYPE {LAN, STEAM}
enum RPC_MODE {CLIENT, SERVER}




enum PERMISSION {SERVER, ALL}

export(MULTIPLAYER_TYPE) var multiplayer_mode = 0

onready var Multiplayer = Global.get_node("Multiplayer")
onready var SteamInit = Global.get_node("Multiplayer/SteamInit")
onready var SteamNetwork = Global.get_node("Multiplayer/SteamInit/SteamNetwork")
onready var SteamLobby = Global.get_node("Multiplayer/SteamInit/SteamLobby")

var debug = false

var rpc_debug_list = {}
var rset_debug_list = {}

func add_rpc_to_debug_list(caller, method):
	if not debug:
		return
	if rpc_debug_list.has(method):
		rpc_debug_list[method] += 1
	else:
		rpc_debug_list[method] = 1

func add_rset_to_debug_list(caller, method):
	if not debug:
		return
	if rset_debug_list.has(method):
		rset_debug_list[method] += 1
	else:
		rset_debug_list[method] = 1

var list_count = 0

func print_debug_list():
	list_count += 1
	
	print("\n[CRUS ONLINE / NETWORK BRIDGE / DEBUG]: Packages debug list #", list_count)
	
	if debug:
		if not rpc_debug_list.empty():
			print("RPC: ", rpc_debug_list)
			rpc_debug_list = {}

		if not rset_debug_list.empty():
			print("RSET: ", rset_debug_list, "\n")
			rset_debug_list = {}

func set_mode(mode):
	match mode:
		MULTIPLAYER_TYPE.LAN:
			print("[CRUS ONLINE / NETWORK BRIDGE]: LAN mode selected")
			multiplayer_mode = MULTIPLAYER_TYPE.LAN
		MULTIPLAYER_TYPE.STEAM:
			print("[CRUS ONLINE / NETWORK BRIDGE]: Steam mode selected")
			multiplayer_mode = MULTIPLAYER_TYPE.STEAM
	

func is_lan():
	return multiplayer_mode == MULTIPLAYER_TYPE.LAN

func is_steam():
	return multiplayer_mode == MULTIPLAYER_TYPE.STEAM

func check_connection():
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			return get_tree().network_peer != null
		MULTIPLAYER_TYPE.STEAM:
			return SteamLobby.in_lobby()

func get_peers():
	return SteamNetwork.get_peers()

func get_id():
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			return get_tree().get_network_unique_id()
		MULTIPLAYER_TYPE.STEAM:
			return SteamInit.steam_id

func get_host_id():
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			return 1
		MULTIPLAYER_TYPE.STEAM:
			return SteamLobby.get_lobby_owner()

func n_is_network_master(node = null):
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			return get_tree().is_network_server() if node == null else node.is_network_master()
		MULTIPLAYER_TYPE.STEAM:
			return SteamNetwork.is_server()


func is_world_authority():
	return get_tree().is_network_server() if is_lan() else SteamNetwork.is_server()

func request_sender(claimed_id):
	if is_lan():
		var sender = get_tree().get_rpc_sender_id()
		if sender != 0:
			return sender
	return get_id() if claimed_id == null else int(claimed_id)

func request_host(caller, method, args = []):
	if not check_connection() or is_world_authority():
		var local_args = args.duplicate()
		local_args.push_front(get_id())
		caller.callv(method, local_args)
	else:
		n_rpc_id(caller, get_host_id(), method, args)

func get_peer_actor(peer_id):
	if check_connection() and not Multiplayer.players.has(peer_id):
		return null
	if Multiplayer.died_players.has(peer_id):
		return null
	if peer_id == get_id():
		return Global.player if is_instance_valid(Global.player) else null
	return Multiplayer.Players.get_node_or_null(str(peer_id))

func check_rpc(caller : Node, method = ""):
	return SteamNetwork.check_permission_hash(caller, method)

func register_rpcs(caller : Node, args):
	SteamNetwork.register_rpcs(caller, args)

func register_rset(caller : Node, method, recived_permission):
	SteamNetwork.register_rset(caller, method, recived_permission)

func n_rpc(caller : Node, method = null, args = []):
	if method == null:
		return
	
	Multiplayer.packages_count += 1
	
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			add_rpc_to_debug_list(caller, method)
			var rpc_args = [method, get_tree().network_peer.get_unique_id()]
			rpc_args.append_array(args)
			caller.callv("rpc", rpc_args)
		MULTIPLAYER_TYPE.STEAM:
			add_rpc_to_debug_list(caller, method)
			if SteamNetwork.is_server():
				SteamNetwork.rpc_all_clients(caller, method, args)
			else:
				SteamNetwork.rpc_on_server(caller, method, args)

func n_rpc_unreliable(caller : Node, method = null, args = []):
	if method == null:
		return
	
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			add_rpc_to_debug_list(caller, method)
			var rpc_args = [method, get_tree().network_peer.get_unique_id()]
			rpc_args.append_array(args)
			caller.callv("rpc_unreliable", rpc_args)
			Multiplayer.packages_count += 1
		MULTIPLAYER_TYPE.STEAM:
			add_rpc_to_debug_list(caller, method)
			SteamNetwork.snapshot_rpc(caller, method, args)

func n_rpc_id(caller : Node, id = 0, method = null, args = []):
	if method == null:
		return
	if int(id) == 0:
		id = get_host_id()
	
	Multiplayer.packages_count += 1
	
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			add_rpc_to_debug_list(caller, method)
			var rpc_args = [id, method, get_tree().network_peer.get_unique_id()]
			rpc_args.append_array(args)
			caller.callv("rpc_id", rpc_args)
		MULTIPLAYER_TYPE.STEAM:
			add_rpc_to_debug_list(caller, method)
			SteamNetwork.rpc_target(int(id), caller, method, args)

func n_rpc_unreliable_id(caller : Node, id = 0, method = null, args = []):
	if method == null:
		return
	
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			add_rpc_to_debug_list(caller, method)
			var rpc_args = [id, method, get_tree().network_peer.get_unique_id()]
			rpc_args.append_array(args)
			caller.callv("rpc_unreliable_id", rpc_args)
			Multiplayer.packages_count += 1
		MULTIPLAYER_TYPE.STEAM:
			add_rpc_to_debug_list(caller, method)
			SteamNetwork.snapshot_rpc(caller, method, args, int(id))

func n_rset(caller : Node, method = null, recived_value = null):
	if method == null:
		return
	
	Multiplayer.packages_count += 1
	
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			add_rset_to_debug_list(caller, method)
			caller.rset(method, recived_value)
		MULTIPLAYER_TYPE.STEAM:
			add_rset_to_debug_list(caller, method)
			SteamNetwork.remote_set(caller, method, recived_value)

func n_rset_unreliable(caller : Node, method = null, recived_value = null):
	if method == null:
		return
	
	Multiplayer.packages_count += 1
	
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			add_rset_to_debug_list(caller, method)
			caller.rset_unreliable(method, recived_value)
		MULTIPLAYER_TYPE.STEAM:
			add_rset_to_debug_list(caller, method)
			SteamNetwork.snapshot_rset(caller, method, recived_value)
