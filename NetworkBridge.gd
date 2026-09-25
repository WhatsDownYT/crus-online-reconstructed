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
var _pending_registrations = []
var damage_source_context = 0
var damage_source_node_context = null
const NPC_SOURCE_ID = 2147483646
const FriendlyFirePolicy = preload("res://MOD_CONTENT/CruS Online/FriendlyFire.gd")

func _counterop():
	if not is_instance_valid(Multiplayer) or not ("CounterOp" in Multiplayer):
		return null
	return Multiplayer.CounterOp

func damage_allowed(source, target, source_node = null):
	if Multiplayer.hostSettings.get("gameMode", "cruelty") == "deathmatch":
		return true
	var counterop = _counterop()
	if source == NPC_SOURCE_ID:
		if is_instance_valid(counterop) and counterop.is_active() and target > 0 and Multiplayer.players.has(target):
			var npc = source_node if is_instance_valid(source_node) else damage_source_node_context
			return not counterop.is_counter_operative(target) or counterop.npc_is_hostile(npc)
		return true
	if is_instance_valid(counterop) and counterop.is_active() and Multiplayer.players.has(source) and Multiplayer.players.has(target):
		return counterop.can_player_damage(source, target, Multiplayer.hostSettings.get("friendlyFire", true))
	return FriendlyFirePolicy.allows(Multiplayer.hostSettings.get("friendlyFire", true), source, target)

func npc_source_id():
	var counterop = _counterop()
	return NPC_SOURCE_ID if is_instance_valid(counterop) and counterop.is_active() else 0

func damage_source_id(source):
	if source == Global.player:
		return get_id()
	if not is_instance_valid(source):
		return damage_source_context
	if source.has_meta("crus_damage_source"):
		return int(source.get_meta("crus_damage_source"))
	if source.has_meta("counterop_npc"):
		return npc_source_id()
	if "drive_id" in source:
		return int(source.drive_id) if source.drive_id != null else 0
	if "player" in source and typeof(source.player) == TYPE_BOOL:
		return get_id() if source.player else npc_source_id()
	var counterop = _counterop()
	if is_instance_valid(counterop) and is_instance_valid(counterop.find_npc_handler(source)):
		return npc_source_id()
	return damage_source_context

func inherit_damage_source(child, source):
	child.set_meta("crus_damage_source", damage_source_id(source))
	var counterop = _counterop()
	if is_instance_valid(counterop) and counterop.npc_is_hostile(source):
		child.set_meta("counterop_hostile", true)

func damage_target_id(target):
	if target == Global.player:
		return get_id()
	if is_instance_valid(target) and "client" in target and is_instance_valid(target.client):
		return int(target.client.name)
	return 0

func npc_damage_allowed(source, target):
	return damage_allowed(npc_source_id(), damage_target_id(target), source)

func apply_damage(source, target, method, args):
	var source_id = damage_source_id(source)
	var clearing_fire = method == "set_fire" and args == [false]
	var counterop = _counterop()
	if not clearing_fire and is_instance_valid(counterop) and Multiplayer.players.has(source_id) and not counterop.allow_npc_action(source_id, target):
		return
	if not clearing_fire and not damage_allowed(source_id, damage_target_id(target), source):
		return
	var previous_source = damage_source_context
	var previous_node = damage_source_node_context
	damage_source_context = source_id
	damage_source_node_context = source
	target.callv(method, args)
	damage_source_context = previous_source
	damage_source_node_context = previous_node

func apply_npc_damage(source, target, method, args):
	if not npc_damage_allowed(source, target):
		return
	var previous_source = damage_source_context
	var previous_node = damage_source_node_context
	damage_source_context = npc_source_id()
	damage_source_node_context = source
	target.callv(method, args)
	damage_source_context = previous_source
	damage_source_node_context = previous_node

func _ready():
	call_deferred("_flush_registrations")

func _flush_registrations():
	if not is_instance_valid(SteamNetwork):
		return
	var pending = _pending_registrations
	_pending_registrations = []
	for entry in pending:
		var caller = entry[0].get_ref()
		if not is_instance_valid(caller) or not caller.is_inside_tree():
			continue
		if entry[1] == "rpc":
			SteamNetwork.register_rpcs(caller, entry[2])
		else:
			SteamNetwork.register_rset(caller, entry[2], entry[3])

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
	if not check_connection():
		return 1
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
	if not check_connection():
		return true
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			return get_tree().is_network_server() if node == null else node.is_network_master()
		MULTIPLAYER_TYPE.STEAM:
			return SteamNetwork.is_server()


func is_world_authority():
	if not check_connection():
		return true
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
	if not is_instance_valid(SteamNetwork):
		_pending_registrations.append([weakref(caller), "rpc", args.duplicate(true)])
		return
	SteamNetwork.register_rpcs(caller, args)

func register_rset(caller : Node, method, recived_permission):
	if not is_instance_valid(SteamNetwork):
		_pending_registrations.append([weakref(caller), "rset", method, recived_permission])
		return
	SteamNetwork.register_rset(caller, method, recived_permission)

func n_rpc(caller : Node, method = null, args = []):
	if method == null or not check_connection() or caller.has_meta("deathmatch_removed"):
		return
	
	Multiplayer.packages_count += 1
	
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			add_rpc_to_debug_list(caller, method)
			var rpc_args = [method, get_tree().network_peer.get_unique_id()]
			rpc_args.append_array(args)
			_lan_broadcast(caller, "rpc_id", rpc_args)
		MULTIPLAYER_TYPE.STEAM:
			add_rpc_to_debug_list(caller, method)
			if SteamNetwork.is_server():
				SteamNetwork.rpc_all_clients(caller, method, args)
			else:
				SteamNetwork.rpc_on_server(caller, method, args)

func n_rpc_unreliable(caller : Node, method = null, args = []):
	if method == null or not check_connection() or caller.has_meta("deathmatch_removed"):
		return
	
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			add_rpc_to_debug_list(caller, method)
			var rpc_args = [method, get_tree().network_peer.get_unique_id()]
			rpc_args.append_array(args)
			_lan_broadcast(caller, "rpc_unreliable_id", rpc_args)
			Multiplayer.packages_count += 1
		MULTIPLAYER_TYPE.STEAM:
			add_rpc_to_debug_list(caller, method)
			SteamNetwork.snapshot_rpc(caller, method, args)

func n_rpc_id(caller : Node, id = 0, method = null, args = []):
	if method == null or not check_connection() or caller.has_meta("deathmatch_removed"):
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
	if method == null or not check_connection() or caller.has_meta("deathmatch_removed"):
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
	if method == null or not check_connection() or caller.has_meta("deathmatch_removed"):
		return
	
	Multiplayer.packages_count += 1
	
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			add_rset_to_debug_list(caller, method)
			_lan_broadcast(caller, "rset_id", [method, recived_value])
		MULTIPLAYER_TYPE.STEAM:
			add_rset_to_debug_list(caller, method)
			SteamNetwork.remote_set(caller, method, recived_value)

func n_rset_unreliable(caller : Node, method = null, recived_value = null):
	if method == null or not check_connection() or caller.has_meta("deathmatch_removed"):
		return
	
	Multiplayer.packages_count += 1
	
	match multiplayer_mode:
		MULTIPLAYER_TYPE.LAN:
			add_rset_to_debug_list(caller, method)
			_lan_broadcast(caller, "rset_unreliable_id", [method, recived_value])
		MULTIPLAYER_TYPE.STEAM:
			add_rset_to_debug_list(caller, method)
			SteamNetwork.snapshot_rset(caller, method, recived_value)

func _lan_broadcast(caller, operation, args):
	for peer in get_tree().get_network_connected_peers():
		var flow = Multiplayer.get("Flow")
		if is_instance_valid(flow) and flow.waiting_world_target(peer, caller):
			continue
		var values = [peer]
		values.append_array(args)
		caller.callv(operation, values)
