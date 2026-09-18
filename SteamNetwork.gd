extends Node

signal peer_status_updated(steam_id)
signal peer_session_failure(steam_id, reason)
signal all_peers_connected()

enum PACKET_TYPE { HANDSHAKE = 1, HANDSHAKE_REPLY = 2, PEER_STATE = 3, NODE_PATH_UPDATE = 4, NODE_PATH_CONFIRM = 5, RPC = 6, RPC_WITH_NODE_PATH = 7, RSET = 8, RSET_WITH_NODE_PATH = 9 }

enum PERMISSION {SERVER, ALL}

var _peers = {}
var _my_steam_id := 0
var _server_steam_id := 0
var _node_path_cache = {}

var _peers_confirmed_node_path = {}
var _next_path_cache_index := 0

var _permissions = {}

const SNAPSHOT_PACKET = 10
const TARGET_REQUEST = 11
const TARGET_DELIVERY = 12
const SCENE_EVENT = 13
const PROTOCOL_VERSION = 2
const SNAPSHOT_CHANNEL = 1
const MAX_PACKETS_PER_FRAME = 128
const PACKET_BUDGET_USEC = 2000
const MAX_PENDING_SNAPSHOTS = 2048
const SNAPSHOT_INTERVAL = 0.05
const SNAPSHOT_MAX_AGE_MSEC = 250
const MAX_UNRELIABLE_BYTES = 1200
var metrics = preload("res://MOD_CONTENT/CruS Online/NetworkMetrics.gd").new()
var _path_to_id = {}
var _registered_nodes = {}
var _pending_snapshots = {}
var _received_sequences = {}
var _snapshot_sequence = 0
var _snapshot_elapsed = 0.0
var scene_epoch = 0
var _snapshots = preload("res://MOD_CONTENT/CruS Online/NetworkSnapshots.gd").new(self)

func begin_scene(epoch):
	scene_epoch = epoch
	_pending_snapshots.clear()
	_received_sequences.clear()
	for entry in _registered_nodes.values():
		entry.pending.clear()
		entry.received.clear()
	clear_node_path_cache()
	metrics.count("scene_transitions")

func diagnostics():
	var result = metrics.sample()
	result["queued_snapshots"] = _pending_snapshots.size()
	result["path_cache"] = _node_path_cache.size()
	result["permissions"] = _permissions.size()
	result["registered_entities"] = _registered_nodes.size()
	result["scene_epoch"] = scene_epoch
	var cancer = get_node_or_null("../../CancerReplication")
	if cancer != null:
		result["cancer_segments"] = cancer.entities.size()
		result["cancer_pending_growth"] = cancer.growth.size()
		result["cancer_pending_damage"] = cancer.hits.size()
	result["objects"] = _object_census()
	result["fps"] = Engine.get_frames_per_second()
	result["static_memory_bytes"] = Performance.get_monitor(Performance.MEMORY_STATIC)
	return result

func _object_census():

	var counts = {"nodes": 0, "dynamic_named": 0, "gibs": 0, "physics_objects": 0, "enemies": 0}
	var pending = [get_tree().root]
	while not pending.empty():
		var node = pending.pop_back()
		counts.nodes += 1
		pending.append_array(node.get_children())
		var label = str(node.name).to_lower()
		if "#" in label:
			counts.dynamic_named += 1
		if "gib" in label:
			counts.gibs += 1
		var script = node.get_script()
		if script != null:
			var path = script.resource_path.get_file()
			if path == "Kinematic_Physics_Object.gd" or node is RigidBody:
				counts.physics_objects += 1
			if path in ["EnemyHandler.gd", "Stupid_Civilian.gd", "flesh_rat.gd"]:
				counts.enemies += 1
	return counts

func _track_registration(caller, permission_key, member, permission, is_property):
	if not caller.has_meta("crus_network_bindings"):
		caller.set_meta("crus_network_bindings", {})
	caller.get_meta("crus_network_bindings")[[member, is_property]] = permission
	var instance_id = caller.get_instance_id()
	if not _registered_nodes.has(instance_id):
		_registered_nodes[instance_id] = {"path": caller.get_path(), "permissions": {}, "paths": {}, "pending": {}, "received": {}}
		if not caller.is_connected("tree_exiting", self, "_unregister_node"):
			caller.connect("tree_exiting", self, "_unregister_node", [instance_id])
		if not caller.is_connected("tree_entered", self, "_restore_registration"):
			caller.connect("tree_entered", self, "_restore_registration", [weakref(caller)])
	_registered_nodes[instance_id].permissions[permission_key] = true

func _restore_registration(reference):
	var caller = reference.get_ref()
	if caller == null:
		return
	var bindings = caller.get_meta("crus_network_bindings")
	for binding in bindings.keys():
		if binding[1]:
			register_rset(caller, binding[0], bindings[binding])
		else:
			register_rpc(caller, binding[0], bindings[binding])

func _unregister_node(instance_id):
	if not _registered_nodes.has(instance_id):
		return
	var entry = _registered_nodes[instance_id]
	for key in entry.permissions:
		_permissions.erase(key)

	for path in entry.paths:
		if _path_to_id.has(path):
			var cache_id = _path_to_id[path]
			_path_to_id.erase(path)
			_node_path_cache.erase(cache_id)
			for confirmations in _peers_confirmed_node_path.values():
				confirmations.erase(cache_id)
	for key in entry.pending:
		_pending_snapshots.erase(key)
	for key in entry.received:
		_received_sequences.erase(key)
	_registered_nodes.erase(instance_id)

func snapshot_rpc(caller, method, args, target = 0):
	if target == 0:
		if is_server():
			for peer_id in _peers:
				if peer_id != _my_steam_id:
					_queue_snapshot(peer_id, caller, method, args, false)
		else:
			_queue_snapshot(get_server_steam_id(), caller, method, args, false)
	else:


		if is_server() or target == get_server_steam_id():
			_queue_snapshot(target, caller, method, args, false)
		else:
			metrics.warn("snapshot_target", method)

func snapshot_rset(caller, property, value):
	if is_server():
		for peer_id in _peers:
			if peer_id != _my_steam_id:
				_queue_snapshot(peer_id, caller, property, value, true)
	else:
		_queue_snapshot(get_server_steam_id(), caller, property, value, true)

func _queue_snapshot(peer_id, caller, member, value, is_property):
	_snapshots.queue(peer_id, caller, member, value, is_property)

func _flush_snapshots():
	_snapshots.flush()

func _handle_snapshot(sender_id, data):
	_snapshots.receive(sender_id, data)

onready var Multiplayer = Global.get_node("Multiplayer")

onready var SteamInit = get_parent()
onready var SteamLobby = $"../SteamLobby"

func init_network():

	SteamLobby.connect("player_joined_lobby", self, "_init_p2p_session")
	SteamLobby.connect("player_left_lobby", self, "_close_p2p_session")
	
	SteamLobby.connect("lobby_created", self, "_init_p2p_host")
	SteamLobby.connect("lobby_owner_changed", self, "_migrate_host")
	
	SteamInit.Steam.connect("p2p_session_request", self, "_on_p2p_session_request")
	SteamInit.Steam.connect("p2p_session_connect_fail", self, "_on_p2p_session_connect_fail")
	
	_my_steam_id = SteamInit.steam_id

func _process(delta):
	var started = OS.get_ticks_usec()
	var processed = 0

	while processed < MAX_PACKETS_PER_FRAME and OS.get_ticks_usec() - started < PACKET_BUDGET_USEC:
		var read_any = false
		for channel in [0, SNAPSHOT_CHANNEL]:
			if processed >= MAX_PACKETS_PER_FRAME or OS.get_ticks_usec() - started >= PACKET_BUDGET_USEC:
				break
			var packet_size = SteamInit.Steam.getAvailableP2PPacketSize(channel)
			if packet_size > 0:
				_read_p2p_packet(packet_size, channel)
				processed += 1
				read_any = true
		if not read_any:
			break
	metrics.frame(OS.get_ticks_usec() - started)
	if processed == MAX_PACKETS_PER_FRAME or OS.get_ticks_usec() - started >= PACKET_BUDGET_USEC:
		metrics.count("receive_budget_hits")
	_snapshot_elapsed += delta
	if _snapshot_elapsed >= SNAPSHOT_INTERVAL:
		_snapshot_elapsed = 0.0
		_flush_snapshots()
	metrics.sample()

func register_rset(caller: Node, property: String, permission: int):
	var node_path = _get_rset_property_path(caller.get_path(), property)
	var perm_hash = _get_permission_hash(node_path)
	_permissions[perm_hash] = permission
	_track_registration(caller, perm_hash, property, permission, true)
	
func register_rpc(caller: Node, method: String, permission: int):
	var perm_hash = _get_permission_hash(caller.get_path(), method)
	_permissions[perm_hash] = permission
	_track_registration(caller, perm_hash, method, permission, false)
	
func register_rpcs(caller: Node, methods: Array):
	for method in methods:
		register_rpc(caller, method[0], method[1])

func clear_node_path_cache():
	_node_path_cache.clear()
	_path_to_id.clear()
	for confirmations in _peers_confirmed_node_path.values():
		confirmations.clear()
	for entry in _registered_nodes.values():
		entry.paths.clear()




func rpc_on_server(caller: Node, method: String, args: Array = []):
	_rpc(get_server_steam_id(), caller, method, args)

func rpc_target(target: int, caller: Node, method: String, args: Array = []):
	if target == 0:
		target = get_server_steam_id()
	if is_server() or target == get_server_steam_id():
		_rpc(target, caller, method, args)
		return
	var packet = PoolByteArray([TARGET_REQUEST])
	packet.append_array(var2bytes([scene_epoch, target, caller.get_path(), method, args]))
	_send_p2p_packet(get_server_steam_id(), packet)

func _handle_target_packet(sender_id, data, delivery):
	if typeof(data) != TYPE_ARRAY or data.size() != 5:
		metrics.warn("invalid_target", "shape")
		return
	if typeof(data[0]) != TYPE_INT or typeof(data[1]) != TYPE_INT or typeof(data[2]) != TYPE_NODE_PATH or typeof(data[3]) != TYPE_STRING or typeof(data[4]) != TYPE_ARRAY:
		metrics.warn("invalid_target", "types")
		return
	if data[0] != scene_epoch:
		metrics.count("scene_mismatch")
		return
	var node = get_node_or_null(data[2])
	if node == null or not node.has_method("validate_network_action"):
		metrics.warn("target_policy_missing", data[3])
		return
	if delivery:
		if is_server() or sender_id != get_server_steam_id() or str(node.name) != str(_my_steam_id):
			return
		if not node.has_method(data[3]) or not _sender_has_permission(sender_id, data[2], data[3]):
			return
		var args = data[4].duplicate()
		args.push_front(data[1])
		node.callv(data[3], args)
		metrics.operation("rpc", data[3])
		return
	if not is_server() or not _peers.has(data[1]) or not _peers[data[1]].connected:
		return
	if not _sender_has_permission(sender_id, data[2], data[3]) or not node.validate_network_action(sender_id, data[1], data[3], data[4]):
		metrics.warn("target_rejected", data[3])
		return
	var packet = PoolByteArray([TARGET_DELIVERY])
	packet.append_array(var2bytes([scene_epoch, sender_id, data[2], data[3], data[4]]))
	_send_p2p_packet(data[1], packet)
	metrics.count("target_relays")



func rpc_on_client(to_peer_id: int, caller: Node, method: String, args: Array = []):
	if not is_server():
		push_warning("Tried to call RPC on client: %s %s" % [caller, method])
		return
	_rpc(to_peer_id, caller, method, args)



func rpc_all_clients(caller: Node, method: String, args: Array = []):
	for peer_id in _peers:
		if peer_id != _my_steam_id:
			rpc_on_client(peer_id, caller, method, args)


func remote_set(caller: Node, property: String, value):

	if is_server():
		for peer in _peers.values():
			if peer.steam_id != _my_steam_id:
				_rset(peer, caller, property, value)
	else:
		var host = get_server_peer()
		if host != null:
			_rset(host, caller, property, value)


func is_peer_connected(steam_id) -> bool:
	if _peers.has(steam_id):
		return _peers[steam_id].connected
	else:
		print("Tried to get status of non-existent peer: %s" % steam_id)
		return false


func get_peer(steam_id):
	if _peers.has(steam_id):
		return _peers[steam_id]
	else:
		print("Tried to get non-existent peer: %s" % steam_id)
		return null


func get_peers() -> Dictionary:
	return _peers


func is_server() -> bool:
	if not _peers.has(_my_steam_id):
		return false
	return _peers[_my_steam_id].host


func get_server_peer():
	return get_peer(get_server_steam_id())


func get_server_steam_id() -> int:
	if _server_steam_id > 0:
		return _server_steam_id
	for peer in _peers.values():
		if peer.host:
			_server_steam_id = peer.steam_id
			return _server_steam_id
	return -1


func peers_connected() -> bool:
	for peer_id in _peers:
		if _peers[peer_id].connected == false:
			return false
	return true

func check_permission_hash(node: Node, method: String = ""):
	var perm_hash = _get_permission_hash(node.get_path(), method)
	return _permissions.has(perm_hash)

func _get_permission_hash(node_path: NodePath, value: String = ""):
	if value.empty():
		return str(node_path).md5_text()
	return (str(node_path) + "::" + value).md5_text()

func _sender_has_permission(sender_id: int, node_path: NodePath, method: String = "") -> bool:
	var perm_hash = _get_permission_hash(node_path, method)
	if not _permissions.has(perm_hash):
		return false
	var permission = _permissions[perm_hash]
	match permission:
		PERMISSION.SERVER:
			return sender_id == get_server_steam_id()
		PERMISSION.ALL:
			return true
	return false

func _migrate_host(old_owner_id, new_owner_id):
	var old_peer = get_peer(old_owner_id)
	if old_peer != null:
		old_peer.host = false
	
	SteamInit.Steam.closeP2PSessionWithUser(old_owner_id)
	
	_server_steam_id = 0
	
	begin_scene(scene_epoch + 1)
	_peers_confirmed_node_path.clear()
	
	_peers.clear()
	for steam_id in SteamLobby.get_lobby_members():
		var p = _create_peer(steam_id)
		_peers[steam_id] = p
	
	var new_owner = get_peer(new_owner_id)
	if new_owner != null:
		new_owner.host = true
	else:
		push_error("Error migrating host, no new host was found!")
		return
	
	if is_server():
		for steam_id in _peers:
			if steam_id != _my_steam_id:
				_init_p2p_session(steam_id)
			else:
				_peers[steam_id].connected = true
			

func _rpc(to_peer_id: int, node: Node, method: String, args: Array):
	if not check_permission_hash(node, method):
		metrics.warn("unregistered_rpc", method)
		return
	var to_peer = get_peer(to_peer_id)
	if to_peer == null:
		push_warning("Cannot send an RPC to a null peer. Check youre completed connected to the network first")
		return

	if not is_peer_connected(_my_steam_id):
		push_warning("Cannot send an RPC when not connected to the network")
		return
		
	if not is_peer_connected(to_peer.steam_id):
		push_warning("Cannot send an RPC to someone who is not connected to the network!")
		return
	
	var node_path = node.get_path()
	var path_cache_index = _get_path_cache(node_path)
	if path_cache_index == -1 and is_server():
		path_cache_index = _add_node_path_cache(node_path)
	
	if to_peer.steam_id == _my_steam_id and is_server():

		_execute_rpc(to_peer, path_cache_index, method, args.duplicate())
		return
	
	if to_peer.steam_id == _my_steam_id:
		push_warning("Client tried to send self an RPC request!")
	
	var packet = PoolByteArray()
	var payload = [path_cache_index, method, args]
	
	if is_server() and not _peer_confirmed_path(to_peer, node_path) or \
		path_cache_index == -1:
		payload.push_front(node_path)
		packet.append(PACKET_TYPE.RPC_WITH_NODE_PATH)
	else:
		packet.append(PACKET_TYPE.RPC)
	
	var serialized_payload = var2bytes(payload)
	
	packet.append_array(serialized_payload)
	_send_scene_event(to_peer.steam_id, packet, method in ["goto_scene_client", "goto_menu_client"])

func _rset(to_peer, node: Node, property: String, value):
	var node_path = _get_rset_property_path(node.get_path(), property)
	if not _permissions.has(_get_permission_hash(node_path)):
		metrics.warn("unregistered_rset", property)
		return
	var path_cache_index = _get_path_cache(node_path)
	if path_cache_index == -1 and is_server():
		path_cache_index = _add_node_path_cache(node_path)
	
	if to_peer.steam_id == _my_steam_id and is_server():

		_execute_rset(to_peer, path_cache_index, value)
		return
	
	var packet = PoolByteArray()
	var payload = [path_cache_index, value]
	if is_server() and not _peer_confirmed_path(to_peer, node_path) or \
		path_cache_index == -1:
		payload.push_front(node_path)
		packet.append(PACKET_TYPE.RSET_WITH_NODE_PATH)
	else:
		packet.append(PACKET_TYPE.RSET)
	
	var serialized_payload = var2bytes(payload)
	packet.append_array(serialized_payload)
	_send_scene_event(to_peer.steam_id, packet)

func _send_scene_event(peer_id, packet, transition = false):
	var envelope = PoolByteArray([SCENE_EVENT])
	envelope.append_array(var2bytes([-1 if transition else scene_epoch, packet]))
	_send_p2p_packet(peer_id, envelope)

func _get_rset_property_path(node_path: NodePath, property: String):
	return NodePath("%s:%s" % [node_path, property])

func _peer_confirmed_path(peer, node_path: NodePath):
	var path_cache_index = _get_path_cache(node_path)
	return _peers_confirmed_node_path.get(peer.steam_id, {}).has(path_cache_index)

func _server_update_node_path_cache(peer_id: int, node_path: NodePath):
	if not is_server():
		return
	var path_cache_index = _get_path_cache(node_path)
	if path_cache_index == -1:
		path_cache_index = _add_node_path_cache(node_path)
	var packet = PoolByteArray()
	var payload = var2bytes([path_cache_index, node_path])
	packet.append(PACKET_TYPE.NODE_PATH_UPDATE)
	packet.append_array(payload)
	_send_p2p_packet(peer_id, packet)

func _update_node_path_cache(sender_id: int, packet_data: PoolByteArray):
	if sender_id != get_server_steam_id():
		return
	var data = bytes2var(packet_data)
	var path_cache_index = data[0]
	var node_path = data[1]
	var node = get_node_or_null(node_path)
	if node == null or not _registered_nodes.has(node.get_instance_id()):
		metrics.count("unknown_path_entity")
		return
	_add_node_path_cache(node_path, path_cache_index)
	_send_p2p_command_packet(get_server_steam_id(), PACKET_TYPE.NODE_PATH_CONFIRM, path_cache_index)

func _server_confirm_peer_node_path(peer_id, path_cache_index: int):
	if not is_server():
		return
	if _peers_confirmed_node_path.has(peer_id) and _node_path_cache.has(path_cache_index):
		_peers_confirmed_node_path[peer_id][path_cache_index] = true

func _add_node_path_cache(node_path: NodePath, path_cache_index: int = -1) -> int:
	var already_exists_id = _get_path_cache(node_path)
	if already_exists_id != -1 and (path_cache_index == -1 or already_exists_id == path_cache_index):
		return already_exists_id
	
	if path_cache_index == -1:
		_next_path_cache_index += 1
		path_cache_index = _next_path_cache_index
	if _node_path_cache.has(path_cache_index):
		_path_to_id.erase(_node_path_cache[path_cache_index])
	if already_exists_id != -1:
		_node_path_cache.erase(already_exists_id)
	_node_path_cache[path_cache_index] = node_path
	_path_to_id[node_path] = path_cache_index
	_next_path_cache_index = max(_next_path_cache_index, path_cache_index)
	var node = get_node_or_null(node_path)
	if node != null and _registered_nodes.has(node.get_instance_id()):
		_registered_nodes[node.get_instance_id()].paths[node_path] = true
	
	return path_cache_index

func _get_node_path(path_cache_index: int):
	return _node_path_cache.get(path_cache_index)

func _get_path_cache(node_path: NodePath) -> int:
	return _path_to_id.get(node_path, -1)

func _create_peer(steam_id):
	var peer = Peer.new()
	peer.steam_id = steam_id
	_peers_confirmed_node_path[steam_id] = {}
	return peer

func _init_p2p_host(lobby_id):
	begin_scene(0)
	print("Initializing P2P Host as %s" % _my_steam_id)
	var host_peer = _create_peer(_my_steam_id)
	host_peer.host = true
	host_peer.connected = true
	_peers[_my_steam_id] = host_peer
	emit_signal("all_peers_connected")
	
func _init_p2p_session(steam_id):
	if not is_server():

		return
	print("Initializing P2P Session with %s" % steam_id)
	_peers[steam_id] = _create_peer(steam_id)
	emit_signal("peer_status_updated", steam_id)
	_send_p2p_command_packet(steam_id, PACKET_TYPE.HANDSHAKE, PROTOCOL_VERSION)

func _close_p2p_session(steam_id):
	if steam_id == _my_steam_id:
		SteamInit.Steam.closeP2PSessionWithUser(_server_steam_id)
		_server_steam_id = 0
		_peers.clear()
		_peers_confirmed_node_path.clear()
		begin_scene(scene_epoch + 1)
		return
	
	print("Closing P2P Session with %s" % steam_id)
	var session_state = SteamInit.Steam.getP2PSessionState(steam_id)
	if session_state.has("connection_active") and session_state["connection_active"]:
		SteamInit.Steam.closeP2PSessionWithUser(steam_id)
	if _peers.has(steam_id):
		_peers.erase(steam_id)
	_peers_confirmed_node_path.erase(steam_id)
	_server_send_peer_state()

func _send_p2p_command_packet(steam_id, packet_type: int, arg = null):
	var payload = PoolByteArray()
	payload.append(packet_type)
	if arg != null:
		payload.append_array(var2bytes(arg))
	if not _send_p2p_packet(steam_id, payload):
		push_error("Failed to send command packet %s" % packet_type)

func _send_p2p_packet(steam_id, data: PoolByteArray, send_type: int = SteamInit.Steam.P2P_SEND_RELIABLE, channel: int = 0) -> bool:
	var sent = SteamInit.Steam.sendP2PPacket(steam_id, data, send_type, channel)
	if sent:
		metrics.traffic("sent", data.size(), send_type >= 2)
	else:
		metrics.count("send_failures")
	return sent

func _broadcast_p2p_packet(data: PoolByteArray, send_type: int = SteamInit.Steam.P2P_SEND_RELIABLE, channel: int = 0):
	for peer_id in _peers:
		if peer_id != _my_steam_id:
			_send_p2p_packet(peer_id, data, send_type, channel)

func _read_p2p_packet(packet_size:int, channel = 0):

	var packet = SteamInit.Steam.readP2PPacket(packet_size, channel)
	

	if packet.empty():
		metrics.warn("empty_packet", str(packet_size))
		return


	var sender_id: int = packet["steam_id_remote"]
	var packet_data: PoolByteArray = packet["data"]

	metrics.traffic("received", packet_data.size(), channel == 0)
	if channel == SNAPSHOT_CHANNEL:
		if packet_data.size() > MAX_UNRELIABLE_BYTES:
			metrics.warn("snapshot_oversize", "received")
			return
		if packet_data.size() > 1 and packet_data[0] == SNAPSHOT_PACKET and _peers.has(sender_id) and _peers[sender_id].connected and (is_server() or sender_id == get_server_steam_id()):
			_handle_snapshot(sender_id, bytes2var(packet_data.subarray(1, packet_data.size() - 1)))
		return
	_handle_packet(sender_id, packet_data)

func _confirm_peer(steam_id):
	if not is_server():
		return
	if not _peers.has(steam_id):
		push_error("Cannot confirm peer %s as they do not exist locally!" % steam_id)
		return
	if _peers[steam_id].connected:
		return
	
	print("Peer Confirmed %s" % steam_id)
	_peers[steam_id].connected = true
	emit_signal("peer_status_updated", steam_id)
	_server_send_peer_state()
	
	if peers_connected():
		print("[CRUS ONLINE / STEAM]: All peers connected")
		emit_signal("all_peers_connected")
	
func _server_send_peer_state():
	if not is_server():
		return
	print("Sending Peer State")
	var peers = []
	for peer in _peers.values():
		peers.append(peer.serialize())
	var payload = PoolByteArray()

	payload.append(PACKET_TYPE.PEER_STATE)

	payload.append_array(var2bytes([scene_epoch, peers]))
	
	_broadcast_p2p_packet(payload)

func _update_peer_state(payload: PoolByteArray):
	if is_server():
		return
	print("Updating Peer State")
	var state = bytes2var(payload)
	if scene_epoch != state[0]:
		begin_scene(state[0])
	var serialized_peers = state[1]
	var new_peers = []
	for serialized_peer in serialized_peers:
		var peer = Peer.new()
		peer.deserialize(serialized_peer)
		prints(peer.steam_id, peer.connected, peer.host)
		if not _peers.has(peer.steam_id) or not peer.eq(_peers[peer.steam_id]):
			_peers[peer.steam_id] = peer
			emit_signal("peer_status_updated", peer.steam_id)
		new_peers.append(peer.steam_id)
	for peer_id in _peers.keys():
		if not peer_id in new_peers:
			_peers.erase(peer_id)
			emit_signal("peer_status_updated", peer_id)
			
func _handle_packet(sender_id, payload: PoolByteArray):
	if payload.size() == 0:
		push_error("Cannot handle an empty packet payload!")
		return
	var packet_type = payload[0]
	var packet_data = null
	if payload.size() > 1:
		packet_data = payload.subarray(1, payload.size()-1)
	if not _peers.has(sender_id):
		metrics.warn("unknown_peer", str(sender_id))
		return
	if not is_server() and sender_id != get_server_steam_id():
		metrics.warn("non_host_packet", str(sender_id))
		return
	if packet_type != PACKET_TYPE.HANDSHAKE_REPLY and not _peers[sender_id].connected:
		metrics.warn("unconnected_peer", str(sender_id))
		return
	if packet_type == TARGET_REQUEST or packet_type == TARGET_DELIVERY:
		if packet_data != null:
			_handle_target_packet(sender_id, bytes2var(packet_data), packet_type == TARGET_DELIVERY)
		return
	if packet_type == SCENE_EVENT:
		if packet_data == null:
			return
		var envelope = bytes2var(packet_data)
		if typeof(envelope) != TYPE_ARRAY or envelope.size() != 2 or typeof(envelope[0]) != TYPE_INT or typeof(envelope[1]) != TYPE_RAW_ARRAY:
			metrics.warn("invalid_envelope", "shape")
			return
		var inner = envelope[1]
		if inner.size() < 2 or not inner[0] in [PACKET_TYPE.RPC, PACKET_TYPE.RPC_WITH_NODE_PATH, PACKET_TYPE.RSET, PACKET_TYPE.RSET_WITH_NODE_PATH]:
			return
		var body = inner.subarray(1, inner.size() - 1)
		if not _valid_packet(inner[0], body):
			return
		if envelope[0] == -1:
			var decoded = bytes2var(body)
			var method_index = 2 if inner[0] == PACKET_TYPE.RPC_WITH_NODE_PATH else 1
			if sender_id != get_server_steam_id() or not inner[0] in [PACKET_TYPE.RPC, PACKET_TYPE.RPC_WITH_NODE_PATH] or not decoded[method_index] in ["goto_scene_client", "goto_menu_client"]:
				return
		elif envelope[0] != scene_epoch:
			metrics.count("scene_mismatch")
			return
		_handle_game_packet(sender_id, inner[0], body)
		return
	if not _valid_packet(packet_type, packet_data):
		metrics.warn("invalid_packet", str(packet_type))
		return
	match packet_type:
		PACKET_TYPE.HANDSHAKE:
			_send_p2p_command_packet(sender_id, PACKET_TYPE.HANDSHAKE_REPLY, PROTOCOL_VERSION)
		PACKET_TYPE.HANDSHAKE_REPLY:
			_confirm_peer(sender_id)
		PACKET_TYPE.PEER_STATE:
			if sender_id != get_server_steam_id():
				return
			_update_peer_state(packet_data)
		PACKET_TYPE.NODE_PATH_CONFIRM:
			_server_confirm_peer_node_path(sender_id, bytes2var(packet_data))
		PACKET_TYPE.NODE_PATH_UPDATE:
			_update_node_path_cache(sender_id, packet_data)
		_:
			metrics.warn("unwrapped_game_packet", str(packet_type))

func _handle_game_packet(sender_id, packet_type, packet_data):
	match packet_type:
		PACKET_TYPE.RPC_WITH_NODE_PATH:
			_handle_rpc_packet_with_path(sender_id, packet_data)
		PACKET_TYPE.RPC:
			_handle_rpc_packet(sender_id, packet_data)
		PACKET_TYPE.RSET_WITH_NODE_PATH:
			_handle_rset_packet_with_path(sender_id, packet_data)
		PACKET_TYPE.RSET:
			handle_rset_packet(sender_id, packet_data)

func _valid_packet(kind, payload):
	if kind == PACKET_TYPE.HANDSHAKE or kind == PACKET_TYPE.HANDSHAKE_REPLY:
		return payload != null and bytes2var(payload) == PROTOCOL_VERSION
	if payload == null:
		return false
	var data = bytes2var(payload)
	if kind == PACKET_TYPE.NODE_PATH_CONFIRM:
		return typeof(data) == TYPE_INT
	if typeof(data) != TYPE_ARRAY:
		return false
	match kind:
		PACKET_TYPE.PEER_STATE:
			if data.size() != 2 or typeof(data[0]) != TYPE_INT or typeof(data[1]) != TYPE_ARRAY or data[1].size() > 16:
				return false
			for item in data[1]:
				if typeof(item) != TYPE_RAW_ARRAY:
					return false
				var peer = bytes2var(item)
				if typeof(peer) != TYPE_ARRAY or peer.size() != 3:
					return false
				if typeof(peer[0]) != TYPE_INT or typeof(peer[1]) != TYPE_BOOL or typeof(peer[2]) != TYPE_BOOL:
					return false
			return true
		PACKET_TYPE.NODE_PATH_UPDATE:
			return data.size() == 2 and typeof(data[0]) == TYPE_INT and typeof(data[1]) == TYPE_NODE_PATH
		PACKET_TYPE.RPC:
			return data.size() == 3 and typeof(data[0]) == TYPE_INT and typeof(data[1]) == TYPE_STRING and typeof(data[2]) == TYPE_ARRAY
		PACKET_TYPE.RPC_WITH_NODE_PATH:
			return data.size() == 4 and typeof(data[0]) == TYPE_NODE_PATH and typeof(data[1]) == TYPE_INT and typeof(data[2]) == TYPE_STRING and typeof(data[3]) == TYPE_ARRAY
		PACKET_TYPE.RSET:
			return data.size() == 2 and typeof(data[0]) == TYPE_INT
		PACKET_TYPE.RSET_WITH_NODE_PATH:
			return data.size() == 3 and typeof(data[0]) == TYPE_NODE_PATH and typeof(data[1]) == TYPE_INT
	return false

func _handle_rset_packet_with_path(sender_id: int, payload: PoolByteArray):
	var peer = get_peer(sender_id)
	var data = bytes2var(payload)
	
	var node_path = data[0]
	var path_cache_index = data[1]
	var value = data[2]
	if get_node_or_null(node_path) == null or not _sender_has_permission(sender_id, node_path):
		metrics.warn("path_permission", str(node_path))
		return
	if is_server():

		path_cache_index = _get_path_cache(node_path)

		if path_cache_index == -1:
			path_cache_index = _add_node_path_cache(node_path)
		_server_update_node_path_cache(sender_id, node_path)
	else:
		_add_node_path_cache(node_path, path_cache_index)
		_send_p2p_command_packet(sender_id, PACKET_TYPE.NODE_PATH_CONFIRM, path_cache_index)
	_execute_rset(peer, path_cache_index, value)

func handle_rset_packet(sender_id: int, payload: PoolByteArray):
	var peer = get_peer(sender_id)
	var data = bytes2var(payload)

	var path_cache_index = data[0]
	var value = data[1]
	
	_execute_rset(peer, path_cache_index, value)
	
func _execute_rset(sender, path_cache_index: int, value):
	var node_path = _get_node_path(path_cache_index)
	if node_path == null:
		metrics.warn("unknown_rset_path", str(path_cache_index))
		return
	
	var node = get_node_or_null(node_path)
	if node == null:
		metrics.warn("missing_rset_entity", str(node_path))
		return
		
	if node_path.get_subname_count() != 1:
		metrics.warn("invalid_rset_property", str(node_path))
		return
	var property:String = node_path.get_subname(0)
	if property == null or property.empty():
		metrics.warn("invalid_rset_property", str(node_path))
		return
		
	if not _sender_has_permission(sender.steam_id, node_path):
		metrics.warn("rset_permission", str(node_path))
		return
	
	metrics.operation("rset", property)
	node.set(property, value)

func _handle_rpc_packet_with_path(sender_id: int, payload: PoolByteArray):
	var peer = get_peer(sender_id)
	var data = bytes2var(payload)
	
	var path_cache_index = data[1]
	var node_path = data[0]
	var method = data[2]
	var args = data[3]
	if get_node_or_null(node_path) == null or not _sender_has_permission(sender_id, node_path, method):
		metrics.warn("path_permission", str(node_path))
		return
	if is_server():

		path_cache_index = _get_path_cache(node_path)

		if path_cache_index == -1:
			path_cache_index = _add_node_path_cache(node_path)
		_server_update_node_path_cache(sender_id, node_path)
	else:
		_add_node_path_cache(node_path, path_cache_index)
		_send_p2p_command_packet(sender_id, PACKET_TYPE.NODE_PATH_CONFIRM, path_cache_index)
	_execute_rpc(peer, path_cache_index, method, args)

func _handle_rpc_packet(sender_id: int, payload: PoolByteArray):
	var peer = get_peer(sender_id)
	var data = bytes2var(payload)
	var path_cache_index = data[0]
	var method = data[1]
	var args = data[2]
	_execute_rpc(peer, path_cache_index, method, args)

func _execute_rpc(sender, path_cache_index: int, method: String, args: Array):
	var node_path = _get_node_path(path_cache_index)
	if node_path == null:
		metrics.warn("unknown_rpc_path", str(path_cache_index))
		return
	
	var node = get_node_or_null(node_path)
	if node == null:
		metrics.warn("missing_rpc_entity", str(node_path))
		return
		
	if not node.has_method(method):
		metrics.warn("missing_rpc_method", method)
		return
	
	if not _sender_has_permission(sender.steam_id, node_path, method):
		metrics.warn("rpc_permission", method)
		return
	if node.has_method("is_target_action") and node.is_target_action(method):
		if str(node.name) != str(_my_steam_id):
			metrics.warn("wrong_target", method)
			return
		if is_server() and sender.steam_id != _my_steam_id and not node.validate_network_action(sender.steam_id, _my_steam_id, method, args):
			metrics.warn("target_rejected", method)
			return
	var owner_state = node.has_method("is_owner_state") and node.is_owner_state(method)
	if owner_state and sender.steam_id != get_server_steam_id() and str(node.name) != str(sender.steam_id):
		metrics.warn("rpc_owner", method)
		return
	
	
	metrics.operation("rpc", method)
	args = args.duplicate()
	args.push_front(sender.steam_id)
	node.callv(method, args)
	if owner_state and is_server() and sender.steam_id != _my_steam_id:
		var forwarded_args = args.duplicate()
		forwarded_args.pop_front()
		for peer_id in _peers:
			if peer_id != _my_steam_id and peer_id != sender.steam_id:
				_rpc(peer_id, node, method, forwarded_args)

func _on_p2p_session_connect_fail(steam_id: int, session_error):

	match session_error:
		SteamInit.Steam.P2P_SESSION_ERROR_NONE:
			push_warning("Session failure with "+str(steam_id)+" [no error given].")
		SteamInit.Steam.P2P_SESSION_ERROR_NOT_RUNNING_APP:
			push_warning("Session failure with "+str(steam_id)+" [target user not running the same game].")
		SteamInit.Steam.P2P_SESSION_ERROR_NO_RIGHTS_TO_APP:
			push_warning("Session failure with "+str(steam_id)+" [local user doesn't own app / game].")
		SteamInit.Steam.P2P_SESSION_ERROR_DESTINATION_NOT_LOGGED_ON:
			push_warning("Session failure with "+str(steam_id)+" [target user isn't connected to Steam].")
		SteamInit.Steam.P2P_SESSION_ERROR_TIMEOUT:
			push_warning("Session failure with "+str(steam_id)+" [connection timed out].")
		SteamInit.Steam.P2P_SESSION_ERROR_MAX:
			push_warning("Session failure with "+str(steam_id)+" [unused].")
		_:
			push_warning("Session failure with "+str(steam_id)+" [unknown error "+str(session_error)+"].")
	
	emit_signal("peer_session_failure", steam_id, session_error)
	if steam_id in _peers:
		_peers[steam_id].connected = false
		emit_signal("peer_status_updated", steam_id)
		_server_send_peer_state()

func _on_p2p_session_request(remote_steam_id):
	print("Received p2p session request from %s" % remote_steam_id)

	var requestor = SteamInit.Steam.getFriendPersonaName(remote_steam_id)
	

	if SteamLobby.get_lobby_owner() == remote_steam_id:
		SteamInit.Steam.acceptP2PSessionWithUser(remote_steam_id)
		
		if not is_peer_connected(_my_steam_id):
			var client_peer = _create_peer(_my_steam_id)
			client_peer.connected = true
			_peers[_my_steam_id] = client_peer
		
		var host_peer = _create_peer(remote_steam_id)
		host_peer.host = true
		host_peer.connected = true
		_peers[remote_steam_id] = host_peer
	else:
		push_warning("Got a rogue p2p session request from %s. Not accepting." % remote_steam_id)

class Peer:
	var connected := false
	var host := false
	
	var steam_id: int
	
	func serialize() -> PoolByteArray:
		var data = [steam_id, connected, host]
		return var2bytes(data)

	func deserialize(data: PoolByteArray):
		var unpacked = bytes2var(data)
		steam_id = unpacked[0]
		connected = unpacked[1]
		host = unpacked[2]
		
	func eq(peer):
		return peer.steam_id == steam_id and \
				peer.host == host and \
				peer.connected == connected
