extends Reference


var _owner
const RPC_ARITY = {"_update_puppet": [4], "_set_transform": [1, 2],
	"client_set_lerp_transform": [1, 2], "set_lerp_transform": [1, 2],
	"network_set_rotation": [1], "set_mech_rotation": [1],
	"set_puppet_transform": [2], "particle_visible": [1],
	"set_animation": [2], "test_rpc": [1]}
const PROPERTY_TYPES = {"global_transform": TYPE_TRANSFORM, "lerp_transform": TYPE_TRANSFORM, "visible": TYPE_BOOL}

func _init(owner):
	_owner = weakref(owner)

func queue(peer_id, caller, member, value, is_property):
	var network = _owner.get_ref()
	if network._waiting_world_target(peer_id, caller):
		return
	if not valid_value(member, value, is_property):
		network.metrics.warn("invalid_snapshot_value", member)
		return
	var permission_path = network._get_rset_property_path(caller.get_path(), member) if is_property else caller.get_path()
	if not network._permissions.has(network._get_permission_hash(permission_path, "" if is_property else member)):
		network.metrics.warn("unregistered_snapshot", member)
		return
	var key = [peer_id, str(caller.get_path()), member, is_property]
	if not network._pending_snapshots.has(key) and network._pending_snapshots.size() >= network.MAX_PENDING_SNAPSHOTS:
		network.metrics.count("snapshot_queue_full")
		return
	if network._pending_snapshots.has(key):
		network.metrics.count("snapshots_coalesced")
	network._snapshot_sequence += 1
	network._registered_nodes[caller.get_instance_id()].pending[key] = true
	network._pending_snapshots[key] = {"peer": peer_id, "path": caller.get_path(),
		"member": member, "value": value, "property": is_property,
		"sequence": network._snapshot_sequence, "time": OS.get_ticks_msec()}

func flush():
	var network = _owner.get_ref()
	var started = OS.get_ticks_usec()
	var processed = 0
	var batches = {}
	for key in network._pending_snapshots.keys():
		if processed >= network.MAX_PENDING_SNAPSHOTS or OS.get_ticks_usec() - started >= network.SNAPSHOT_SEND_BUDGET_USEC:
			network.metrics.count("send_budget_hits")
			break
		var state = network._pending_snapshots[key]
		network._pending_snapshots.erase(key)
		processed += 1
		if not network._peers.has(state.peer) or not network._peers[state.peer].connected:
			continue
		if OS.get_ticks_msec() - state.time > network.SNAPSHOT_MAX_AGE_MSEC:
			network.metrics.count("snapshots_expired")
			continue
		var value = [network.scene_epoch, state.sequence, state.path, state.member, state.value, state.property]
		if var2bytes(value).size() + 1 > network.MAX_UNRELIABLE_BYTES:
			network.metrics.warn("snapshot_oversize", state.member)
			continue
		var batch = batches.get(state.peer, [])
		var candidate = batch.duplicate()
		candidate.append(value)
		if candidate.size() > 16 or var2bytes(candidate).size() + 1 > network.MAX_UNRELIABLE_BYTES:
			_send_batch(state.peer, batch)
			batch = []
		batch.append(value)
		batches[state.peer] = batch
	for peer in batches:
		_send_batch(peer, batches[peer])

func _send_batch(peer, batch):
	if batch.empty():
		return
	var network = _owner.get_ref()
	var packet = PoolByteArray([network.SNAPSHOT_PACKET if batch.size() == 1 else network.SNAPSHOT_BATCH])
	packet.append_array(var2bytes(batch[0] if batch.size() == 1 else batch))
	network._send_p2p_packet(peer, packet, 1, network.SNAPSHOT_CHANNEL)
	network.metrics.count("snapshot_states_sent", batch.size())

func receive_batch(sender_id, data):
	if typeof(data) != TYPE_ARRAY or data.empty() or data.size() > 16:
		_owner.get_ref().metrics.warn("invalid_snapshot_batch", "shape")
		return
	for state in data:
		receive(sender_id, state)

func receive(sender_id, data):
	var network = _owner.get_ref()
	if typeof(data) != TYPE_ARRAY or data.size() != 6:
		network.metrics.warn("invalid_snapshot", "shape")
		return
	if typeof(data[0]) != TYPE_INT or typeof(data[1]) != TYPE_INT or typeof(data[2]) != TYPE_NODE_PATH or typeof(data[3]) != TYPE_STRING or typeof(data[5]) != TYPE_BOOL:
		network.metrics.warn("invalid_snapshot", "types")
		return
	if data[0] != network.scene_epoch:
		network.metrics.count("scene_mismatch")
		return
	var path = data[2]
	var member = data[3]
	if not valid_value(member, data[4], data[5]):
		network.metrics.warn("invalid_snapshot_value", member)
		return
	var node = network.get_node_or_null(path)
	if node == null:
		network.metrics.count("unknown_snapshot_entity")
		return
	if not data[5] and node.has_method("is_target_action") and node.is_target_action(member):
		network.metrics.warn("gameplay_as_snapshot", member)
		return
	var permission_path = network._get_rset_property_path(path, member) if data[5] else path
	if not network._sender_has_permission(sender_id, permission_path, "" if data[5] else member):
		network.metrics.warn("snapshot_permission", member)
		return

	if member == "_update_puppet" and sender_id != network.get_server_steam_id() and str(node.name) != str(sender_id):
		network.metrics.warn("snapshot_owner", member)
		return
	if member == "set_lerp_transform" and sender_id != network.get_server_steam_id():
		if "physics_revision" in node and data[4].size() == 2 and data[4][1] != node.physics_revision:
			network.metrics.count("stale_snapshots")
			return
		var owner_id = node.get("drive_id") if "drive_id" in node else node.get("holdId")
		if owner_id != sender_id:
			network.metrics.warn("snapshot_owner", member)
			return
	var key = [sender_id, str(path), member, data[5]]
	if data[1] <= network._received_sequences.get(key, -1):
		network.metrics.count("stale_snapshots")
		return
	network._received_sequences[key] = data[1]
	network._registered_nodes[node.get_instance_id()].received[key] = true
	if data[5]:
		network.metrics.operation("rset", member)
		node.set(member, data[4])
	elif typeof(data[4]) == TYPE_ARRAY and node.has_method(member):
		network.metrics.operation("rpc", member)
		var args = data[4].duplicate()
		args.push_front(sender_id)
		node.callv(member, args)

func valid_value(member, value, is_property):
	if is_property:
		return PROPERTY_TYPES.has(member) and typeof(value) == PROPERTY_TYPES[member] and finite_value(value)
	if not RPC_ARITY.has(member) or typeof(value) != TYPE_ARRAY or not value.size() in RPC_ARITY[member]:
		return false
	match member:
		"_update_puppet":
			return typeof(value[0]) == TYPE_TRANSFORM and finite_value(value[0]) and typeof(value[1]) == TYPE_ARRAY and value[1].size() == 2 and number(value[1][0]) and number(value[1][1]) and number(value[2]) and (value[3] == null or typeof(value[3]) == TYPE_VECTOR3 and finite_value(value[3]))
		"_set_transform":
			return typeof(value[0]) == TYPE_TRANSFORM and finite_value(value[0]) and (value.size() == 1 or typeof(value[1]) == TYPE_VECTOR3 and finite_value(value[1]) or typeof(value[1]) == TYPE_INT and value[1] >= 0)
		"client_set_lerp_transform", "set_lerp_transform":
			return typeof(value[0]) == TYPE_TRANSFORM and finite_value(value[0]) and (value.size() == 1 or typeof(value[1]) == TYPE_INT and value[1] >= 0)
		"set_puppet_transform":
			return typeof(value[0]) == TYPE_VECTOR3 and typeof(value[1]) == TYPE_VECTOR3 and finite_value(value[0]) and finite_value(value[1])
		"network_set_rotation", "set_mech_rotation":
			return number(value[0])
		"particle_visible":
			return typeof(value[0]) == TYPE_BOOL
		"set_animation":
			return typeof(value[0]) == TYPE_STRING and value[0].length() < 128 and number(value[1])
		"test_rpc":
			return typeof(value[0]) == TYPE_ARRAY and value[0].size() <= 16
	return false

func number(value):
	return typeof(value) in [TYPE_INT, TYPE_REAL] and not is_nan(value) and not is_inf(value)

func finite_value(value):
	if typeof(value) == TYPE_TRANSFORM:
		return finite_value(value.origin) and finite_value(value.basis.x) and finite_value(value.basis.y) and finite_value(value.basis.z)
	if typeof(value) == TYPE_VECTOR3:
		return number(value.x) and number(value.y) and number(value.z)
	return true
