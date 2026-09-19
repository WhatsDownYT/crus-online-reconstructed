extends Node

const Network = preload("res://MOD_CONTENT/CruS Online/SteamNetwork.gd")
const Bridge = preload("res://MOD_CONTENT/CruS Online/NetworkBridge.gd")
const Policy = preload("res://MOD_CONTENT/CruS Online/PlayerActionPolicy.gd")
var failures = 0

class MultiplayerFixture:
	extends Node
	var Flow
	var hostSettings = {"friendlyFire": true}
	var players = {1: {}, 2: {}, 3: {}}
	var died_players = []
	var Players
	var completions = 0
	func goto_menu_host(_complete = false):
		completions += 1

class FlashSoulFixture:
	extends Spatial
	var enabled = true

class FlashBodyFixture:
	extends Spatial
	var dead = false
	var muzzleflash

class CollisionOwnerFixture:
	extends Spatial
	var playerCrouch = false
	var death = false
	var NetworkBridge

class NotifyFixture:
	extends Control
	var wipes = 0
	func apply_team_wipe():
		wipes += 1
	var messages = []
	func set_health(_value):
		pass
	func notify(_text, _color):
		messages.append(_text)
	func set_death_label():
		pass

class MenuExitFixture:
	extends "res://MOD_CONTENT/CruS Online/multiplayer.gd"
	var destinations = []
	func goto_menu_host(completed = false, level_select = false):
		destinations.append([completed, level_select])

class WaitingFlowFixture:
	extends Node
	var requests = []
	var waiting_peers = []
	var ending = ""
	func ending_path():
		return ending
	func request_wait(peer, level_select):
		requests.append([peer, level_select])

class MenuStateFixture:
	extends Control
	var in_game = true

class DamageReceiver:
	extends Spatial
	var client = null
	var health = 100
	var bridge
	var source_seen = -1
	func damage(amount):
		health -= amount
		source_seen = bridge.damage_source_context

class WeaponSource:
	extends Node
	var player = true

class ObjectiveCounter:
	extends Reference
	var CURRENT_LEVEL = 0
	var objectives = 0
	var removals = 0
	func add_objective():
		objectives += 1
	func remove_objective():
		objectives -= 1
		removals += 1

class ExitFixture:
	extends "res://MOD_CONTENT/CruS Online/remaped/Exit.gd"
	var presence = []
	func _collect_exit_peers():
		return presence.duplicate()

class FakeSteam:
	extends Reference
	var P2P_SEND_RELIABLE = null
	var incoming = {0: [], 1: []}
	var sent = []
	var closed = []
	var accepted = []
	var joins = []
	func closeP2PSessionWithUser(peer):
		closed.append(peer)
	func acceptP2PSessionWithUser(peer):
		accepted.append(peer)
	func joinLobby(lobby):
		joins.append(lobby)
	func leaveLobby(_lobby):
		pass
	func getAvailableP2PPacketSize(channel):
		return 0 if incoming[channel].empty() else incoming[channel][0].data.size()
	func readP2PPacket(_size, channel):
		return incoming[channel].pop_front()
	func sendP2PPacket(peer, data, mode, channel):
		sent.append([peer, data, mode, channel])
		return true

class SteamParent:
	extends Node
	var Steam = FakeSteam.new()
	var steam_id = 1

class LobbyFixture:
	extends Node
	var active = true
	var lobby_owner = 1
	func get_lobby_members():
		return {1: "one", 2: "two", 3: "three"}
	func in_lobby():
		return active
	func get_lobby_owner():
		return lobby_owner

class Entity:
	extends Node
	var received = []
	var state = 0
	func network_set_rotation(sender, value):
		received.append([sender, value])

class Target:
	extends Entity
	func is_target_action(method):
		return method == "effect"
	func validate_network_action(sender, target, method, args):
		return sender == 2 and str(name) == str(target) and method == "effect" and args == [123]
	func effect(sender, value):
		received.append([sender, value])

class OwnerState:
	extends Entity
	func is_owner_state(method):
		return method == "set_flashlight"
	func set_flashlight(sender, value):
		received.append([sender, value])

class ElevatorBridge:
	extends Node
	var damage_source_context = 0
	func inherit_damage_source(child, _source):
		child.set_meta("crus_damage_source", 0)
	enum PERMISSION {SERVER, ALL}
	var authority = true
	var online = true
	var net
	var events = []
	var actor
	func get_id():
		return 1
	func get_host_id():
		return 1
	func request_sender(id):
		return 1 if id == null else id
	func get_peer_actor(id):
		return actor if id in [1, 2, 3] else null
	func check_connection():
		return online
	func is_world_authority():
		return authority
	func n_is_network_master(_node = null):
		return authority
	func register_rpcs(caller, entries):
		net.register_rpcs(caller, entries)
	func register_rset(caller, property, permission):
		net.register_rset(caller, property, permission)
	func n_rpc(_caller, method, args = []):
		events.append([method, args])
	func n_rpc_unreliable(_caller, method, args = []):
		events.append([method, args])
	func request_host(caller, method, args = []):
		var values = args.duplicate()
		values.push_front(get_id())
		caller.callv(method, values)
	func n_rpc_id(_caller, peer, method, args = []):
		events.append([method, args, peer])

class GibFixture:
	extends Spatial
	var velocity = Vector3.ZERO

class GrappleReceiver:
	extends Reference
	var point
	func set_grapple(value):
		point = value

class ImplantMenuFixture:
	extends Node
	func clear_equips():
		pass
	func update_buttons():
		pass

class CancerNpcFixture:
	extends Spatial
	var dead = false
	var enabled = true
	var cancer_immunity = false
	var armor = 0
	var objective_removals = 0
	func remove_objective():
		objective_removals += 1

class LifePuppet:
	extends Spatial
	var death = false
	var resets = 0
	func is_owner_state(_method):
		return true
	func play_explosion_sound():
		death = true
	func _set_death(_id, value):
		death = value
	func player_restart():
		death = false
		resets += 1

class SightActor:
	extends Spatial
	var aim_point

class SightRay:
	extends RayCast
	var refreshed = 0
	var collider = null
	func force_raycast_update():
		refreshed += 1
	func is_colliding():
		return collider != null
	func get_collider():
		return collider

class PropFixture:
	extends "res://MOD_CONTENT/CruS Online/remaped/Kinematic_Physics_Object.gd"
	func step(delta):
		._physics_process(delta)
	var transform_changes = 0
	func _notification(what):
		if what == 44:
			transform_changes += 1
	func _ready():
		glob = Global
		register_all_rpcs()
		set_physics_process(false)

var host_departures = 0
func record_host_departure():
	host_departures += 1

func _ready():
	call_deferred("run")

func check(condition, label):
	if not condition:
		failures += 1
		printerr("FAIL: ", label)

func run():
	var root = get_tree().root
	for path in ["multiplayer.gd", "multiplayer_player.gd", "SteamLobby.gd", "multiplayer_menu.gd", "Players.gd", "Menu.gd", "Stats.gd", "ChatBox.gd", "entities/Enemy_Torso.gd", "remaped/Kinematic_Physics_Object.gd", "remaped/Divine_Door.gd", "remaped/Profane_Door.gd", "remaped/Elevator.gd", "remaped/weapon.gd", "remaped/Exit.gd", "remaped/Game_Manager.gd", "entities/EnemyHandler.gd"]:
		var script = load("res://MOD_CONTENT/CruS Online/" + path)
		check(script != null and script.can_instance(), "Godot compiles " + path)
	var multiplayer = MultiplayerFixture.new()
	multiplayer.name = "Multiplayer"
	Global.add_child(multiplayer)
	var parent = SteamParent.new()
	parent.name = "SteamInit"
	multiplayer.add_child(parent)
	var lobby = LobbyFixture.new()
	lobby.name = "SteamLobby"
	parent.add_child(lobby)
	var net = Network.new()
	net.name = "SteamNetwork"
	parent.add_child(net)
	net.set_process(false)
	net._my_steam_id = 1
	net._server_steam_id = 1
	var early_bridge = Bridge.new()
	var early_entity = Entity.new()
	root.add_child(early_entity)
	var early_definitions = [["network_set_rotation", net.PERMISSION.ALL]]
	early_bridge.register_rpcs(early_entity, early_definitions)
	early_bridge.register_rset(early_entity, "state", net.PERMISSION.SERVER)
	early_definitions.clear()
	var removed_before_ready = Entity.new()
	root.add_child(removed_before_ready)
	early_bridge.register_rpcs(removed_before_ready, [["network_set_rotation", net.PERMISSION.ALL]])
	removed_before_ready.free()
	check(early_bridge._pending_registrations.size() == 3, "registrations before bridge ready are queued without touching null network")
	multiplayer.add_child(early_bridge)
	early_bridge._flush_registrations()
	check(early_bridge._pending_registrations.empty(), "startup registrations flushed after bridge initializes")
	check(net._registered_nodes.has(early_entity.get_instance_id()) and net._registered_nodes[early_entity.get_instance_id()].permissions.size() == 2, "early RPC and property permissions survive offline startup")
	early_bridge._flush_registrations()
	lobby.active = false
	for offline_mode in [0, 1]:
		early_bridge.set_mode(offline_mode)
		check(not early_bridge.check_connection(), "no lobby or ENet peer means offline")
		check(early_bridge.n_is_network_master() and early_bridge.is_world_authority(), "offline world simulates locally in either transport mode")
		check(early_bridge.get_id() == 1, "offline actor ID is available without a network peer")
		early_bridge.n_rpc(early_entity, "network_set_rotation", [12])
		early_bridge.n_rpc_id(early_entity, 1, "network_set_rotation", [12])
		early_bridge.n_rpc_unreliable(early_entity, "network_set_rotation", [12])
		early_bridge.n_rpc_unreliable_id(early_entity, 1, "network_set_rotation", [12])
		early_bridge.n_rset(early_entity, "state", 12)
		early_bridge.n_rset_unreliable(early_entity, "state", 12)
	check(parent.Steam.sent.empty() and early_entity.received.empty(), "offline replication sends nothing")
	lobby.active = true
	early_entity.free()
	early_bridge.free()
	for peer_id in [1, 2, 3]:
		var peer = net._create_peer(peer_id)
		peer.connected = true
		peer.host = peer_id == 1
		net._peers[peer_id] = peer
	var entity = Entity.new()
	entity.name = "Entity"
	root.add_child(entity)
	net.register_rpc(entity, "network_set_rotation", net.PERMISSION.ALL)
	net.register_rset(entity, "state", net.PERMISSION.SERVER)
	var waiting_level = Node.new()
	waiting_level.name = "Level"
	root.add_child(waiting_level)
	var waiting_entity = Entity.new()
	waiting_level.add_child(waiting_entity)
	multiplayer.Flow = load("res://MOD_CONTENT/CruS Online/SessionFlow.gd").new()
	multiplayer.Flow.Multiplayer = multiplayer
	multiplayer.Flow.waiting_peers = [2]
	multiplayer.Players = Node.new()
	multiplayer.add_child(multiplayer.Players)
	net.register_rpc(waiting_entity, "network_set_rotation", net.PERMISSION.ALL)
	parent.Steam.sent.clear()
	net._rpc(2, waiting_entity, "network_set_rotation", [1])
	net.snapshot_rpc(waiting_entity, "network_set_rotation", [1])
	check(parent.Steam.sent.empty() and net._pending_snapshots.size() == 1, "waiting Steam peer receives no world RPC or snapshot while active peer still does")
	check(not multiplayer.Flow.waiting_world_target(2, multiplayer), "lobby control messages still reach waiting peers")
	net._pending_snapshots.clear()
	waiting_level.free()
	multiplayer.Flow.free()
	multiplayer.Flow = null
	multiplayer.Players.free()
	multiplayer.Players = null
	var definitions = [["network_set_rotation", net.PERMISSION.ALL]]
	net.register_rpcs(entity, definitions)
	net.register_rpcs(entity, definitions)
	check(definitions[0].size() == 2, "registration does not mutate definitions")
	var cache_id = net._add_node_path_cache(entity.get_path())
	check(net._add_node_path_cache(entity.get_path()) == cache_id, "path allocation idempotent")
	check(net._get_path_cache(entity.get_path()) == cache_id, "reverse path lookup")
	net._server_update_node_path_cache(2, entity.get_path())
	check(parent.Steam.sent.back()[1][0] == net.PACKET_TYPE.NODE_PATH_UPDATE, "path update header")
	net._server_confirm_peer_node_path(2, cache_id)
	net._server_confirm_peer_node_path(2, cache_id)
	check(net._peers_confirmed_node_path[2].size() == 1, "ack deduplication")
	parent.Steam.sent.clear()
	for i in range(100):
		net.snapshot_rpc(entity, "network_set_rotation", [i])
	check(net._pending_snapshots.size() == 2, "coalescing latest state per recipient")
	net._flush_snapshots()
	check(parent.Steam.sent.size() == 2, "one snapshot per recipient")
	for packet in parent.Steam.sent:
		check(packet[2] == 1 and packet[3] == 1, "disposable Steam channel")
		var state = bytes2var(packet[1].subarray(1, packet[1].size() - 1))
		check(state[4] == [99], "latest state retained")
	parent.Steam.sent.clear()
	var batch_entities = []
	for number in range(20):
		var batch_entity = Entity.new()
		root.add_child(batch_entity)
		net.register_rpc(batch_entity, "network_set_rotation", net.PERMISSION.ALL)
		net.snapshot_rpc(batch_entity, "network_set_rotation", [number])
		batch_entities.append(batch_entity)
	for _flush in range(4):
		net._flush_snapshots()
	check(net._pending_snapshots.empty() and parent.Steam.sent.size() < 40, "multiple entity updates share packets instead of one packet per entity")
	var sent_states = 0
	for packed in parent.Steam.sent:
		check(packed[1].size() <= net.MAX_UNRELIABLE_BYTES, "batched snapshots stay within packet limit")
		var payload = bytes2var(packed[1].subarray(1, packed[1].size() - 1))
		var states = payload if packed[1][0] == net.SNAPSHOT_BATCH else [payload]
		sent_states += states.size()
		if packed[0] == 2:
			net._snapshots.receive_batch(2, states)
	check(sent_states == 40, "snapshot batching preserves every entity and recipient")
	for batch_entity in batch_entities:
		check(batch_entity.received.size() == 1, "batched entity state applies once")
		batch_entity.free()
	var snapshot = [0, 5, entity.get_path(), "network_set_rotation", [42], false]
	net._handle_snapshot(2, snapshot)
	snapshot[1] = 4
	net._handle_snapshot(2, snapshot)
	check(entity.received == [[2, 42]], "out-of-order state rejected")
	snapshot[0] = 99
	snapshot[1] = 6
	net._handle_snapshot(2, snapshot)
	check(entity.received.size() == 1, "wrong scene rejected")
	for i in range(500):
		parent.Steam.incoming[0].append({"steam_id_remote": 2, "data": PoolByteArray([1])})
	net._process(0.001)
	check(parent.Steam.incoming[0].size() >= 372, "receive packet budget")
	check(net.metrics.totals.get("receive_budget_hits", 0) > 0, "budget instrumentation")
	parent.Steam.incoming[0].clear()
	check(not net._valid_packet(net.PACKET_TYPE.RPC, var2bytes([1])), "truncated RPC rejected")
	check(not net._valid_packet(255, var2bytes([])), "unknown packet rejected")
	check(net._valid_packet(net.PACKET_TYPE.HANDSHAKE, var2bytes(net.PROTOCOL_VERSION)), "versioned handshake")
	check(not net._valid_packet(net.PACKET_TYPE.HANDSHAKE, null), "legacy handshake rejected")
	var joining_client = Network.new()
	parent.add_child(joining_client)
	joining_client.set_process(false)
	joining_client._my_steam_id = 2
	joining_client.begin_scene(1)
	for peer_id in [1, 2]:
		var joining_peer = joining_client._create_peer(peer_id)
		joining_peer.connected = true
		joining_peer.host = peer_id == 1
		joining_client._peers[peer_id] = joining_peer
	parent.Steam.sent.clear()
	net._server_send_peer_state()
	check(parent.Steam.sent.size() == 2, "peer-state broadcast reaches every remote peer without native constants")
	check(parent.Steam.sent[0][2] == 2 and parent.Steam.sent[0][3] == 0, "peer-state broadcast uses reliable channel zero")
	var state_packet = parent.Steam.sent[0][1]
	check(joining_client._valid_packet(net.PACKET_TYPE.PEER_STATE, state_packet.subarray(1, state_packet.size() - 1)), "host peer-state packet passes client validation")
	joining_client._handle_packet(1, state_packet)
	check(joining_client.scene_epoch == net.scene_epoch, "joining client adopts host epoch before gameplay RPCs")
	joining_client.free()

	net.register_rpc(entity, "test_rpc", net.PERMISSION.SERVER)
	parent.Steam.sent.clear()
	net.snapshot_rpc(entity, "test_rpc", [["x".repeat(2000)]])
	net._flush_snapshots()
	check(parent.Steam.sent.empty(), "oversize snapshot has no reliable fallback")
	check(net.metrics.totals.get("warning_snapshot_oversize", 0) == 2, "oversize diagnostics")

	var target = Target.new()
	target.name = "3"
	root.add_child(target)
	net.register_rpc(target, "effect", net.PERMISSION.ALL)
	parent.Steam.sent.clear()
	net._my_steam_id = 2
	net.rpc_target(3, target, "effect", [123])
	check(parent.Steam.sent.size() == 1 and parent.Steam.sent[0][0] == 1, "A request sent to host")
	var request = parent.Steam.sent.pop_front()[1]
	net._my_steam_id = 1
	net._handle_packet(2, request)
	check(target.received.empty(), "relay never executes on host local player")
	check(parent.Steam.sent.size() == 1 and parent.Steam.sent[0][0] == 3, "host preserves destination B")
	var delivery = parent.Steam.sent.pop_front()[1]
	net._my_steam_id = 3
	net._handle_packet(1, delivery)
	check(target.received == [[2, 123]], "B receives original source A")
	net._handle_packet(2, delivery)
	check(target.received.size() == 1, "direct client delivery rejected")
	net._my_steam_id = 1
	net._handle_target_packet(2, [0, 3, target.get_path(), "effect", [999]], false)
	check(parent.Steam.sent.empty(), "invalid action rejected by host policy")

	net.rpc_target(3, target, "effect", [456])
	var host_event = parent.Steam.sent.pop_front()[1]
	net._my_steam_id = 3
	net._handle_packet(1, host_event)
	check(target.received.back() == [1, 456], "host to client event")
	parent.Steam.sent.clear()
	net.begin_scene(1)
	net._handle_packet(1, host_event)
	check(target.received.size() == 2, "old reliable scene event rejected")
	net._my_steam_id = 1
	net.begin_scene(0)
	target.free()

	var host_target = Target.new()
	host_target.name = "1"
	root.add_child(host_target)
	net.register_rpc(host_target, "effect", net.PERMISSION.ALL)
	var host_path = net._add_node_path_cache(host_target.get_path())
	net._execute_rpc(net._peers[2], host_path, "effect", [999])
	check(host_target.received.empty(), "host target policy rejects invalid damage")
	net._execute_rpc(net._peers[2], host_path, "effect", [123])
	check(host_target.received == [[2, 123]], "client to host valid action")
	net._handle_snapshot(2, [0, 100, host_target.get_path(), "effect", [123], false])
	check(host_target.received.size() == 1, "target action cannot bypass policy through snapshots")
	host_target.free()
	var owner = OwnerState.new()
	owner.name = "2"
	root.add_child(owner)
	net.register_rpc(owner, "set_flashlight", net.PERMISSION.ALL)
	var owner_path = net._add_node_path_cache(owner.get_path())
	parent.Steam.sent.clear()
	net._execute_rpc(net._peers[2], owner_path, "set_flashlight", [true])
	check(owner.received == [[2, true]], "owner visual state applied on host")
	check(parent.Steam.sent.size() == 1 and parent.Steam.sent[0][0] == 3, "visual state relays to B without echo to A")
	net._execute_rpc(net._peers[3], owner_path, "set_flashlight", [false])
	check(owner.received.size() == 1, "other player cannot publish owner state")
	owner.free()
	check(Policy.validate("_do_damage", [25, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 0, 2], true, false), "valid player damage")
	check(not Policy.validate("_do_damage", [-1, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 0, 2], true, false), "negative damage rejected")
	check(not Policy.validate("_set_cancer", [], false, false), "invulnerable target protected")
	check(not Policy.validate("give_money", [], true, false), "arbitrary gameplay method rejected")
	check(net._snapshots.valid_value("_set_transform", [Transform.IDENTITY, 3], false), "door revision is accepted in movement snapshots")
	check(not net._snapshots.valid_value("_set_transform", [Transform.IDENTITY, -1], false), "negative door revision rejected")
	var command = load("res://MOD_CONTENT/CruS Online/remaped/Player.gd").Cmd.new()
	check(net._snapshots.valid_value("_update_puppet", [Transform.IDENTITY, [command.forward_move, command.right_move], 0.0, null], false), "new player input is valid before first movement tick")
	var old_entity_path = entity.get_path()
	entity.name = "RenamedProjectile"
	check(net.check_permission_hash(entity, "network_set_rotation"), "renamed projectile keeps RPC registration")
	check(not net._permissions.has(net._get_permission_hash(old_entity_path, "network_set_rotation")), "renamed projectile discards old permission path")
	check(net._get_path_cache(old_entity_path) == -1, "renamed projectile discards old path cache")

	root.remove_child(entity)
	check(net._permissions.empty(), "permissions removed on tree exit")
	check(net._node_path_cache.empty(), "path removed on tree exit")
	multiplayer.add_child(entity)
	check(net.check_permission_hash(entity, "network_set_rotation"), "permissions restored after reparent")
	entity.free()
	check(net._registered_nodes.empty(), "no stale entity references")
	check(net._permissions.empty(), "no stale permissions")
	check(net._received_sequences.empty(), "no stale sequence entries")

	var stress_start = OS.get_ticks_usec()
	for cycle in range(10):
		var transients = []
		for i in range(200):
			var transient = Entity.new()
			root.add_child(transient)
			net.register_rpc(transient, "network_set_rotation", net.PERMISSION.ALL)
			net._add_node_path_cache(transient.get_path())
			transients.append(transient)
		check(net._registered_nodes.size() == 200 and net._node_path_cache.size() == 200, "200 simultaneously registered entities")
		for transient in transients:
			transient.free()
		net.begin_scene(cycle + 1)
		check(net._permissions.empty() and net._node_path_cache.empty(), "mission-cycle cleanup")
	print("SYNTHETIC_LIFECYCLE cycles=10 entities_per_cycle=200 elapsed_usec=", OS.get_ticks_usec() - stress_start)
	check(net.diagnostics().registered_entities == 0, "diagnostic census")
	var elevator_bridge = ElevatorBridge.new()
	elevator_bridge.net = net
	elevator_bridge.name = "NetworkBridge"
	multiplayer.add_child(elevator_bridge)
	var elevator = load("res://MOD_CONTENT/CruS Online/remaped/Elevator.gd").new()
	root.add_child(elevator)
	elevator.set_process(false)
	check(elevator.speed == -2 and elevator.initpos, "vanilla elevator initial state")
	elevator.stop()
	check(elevator.speed == 2 and not elevator.initpos, "no-argument initial stopper reverses elevator")
	elevator.use()
	check(not elevator.stopped, "elevator use starts movement")
	elevator.stop()
	check(elevator.speed == -2 and elevator.stopped, "arrival stopper reverses next trip")
	elevator_bridge.authority = false
	elevator.stop()
	check(elevator.speed == -2 and elevator_bridge.events.size() == 3, "client collision cannot reverse host elevator")
	elevator.sync_state(1, Transform.IDENTITY, false, 2, false)
	check(elevator.speed == 2 and not elevator.stopped, "client receives elevator state")
	elevator.free()
	elevator_bridge.authority = true
	elevator_bridge.actor = Spatial.new()
	root.add_child(elevator_bridge.actor)
	var prop = PropFixture.new()
	var shape = CollisionShape.new()
	shape.name = "CollisionShape"
	prop.add_child(shape)
	prop.collision_layer = 5
	prop.collision_mask = 3
	root.add_child(prop)
	var original_layer = prop.collision_layer
	var original_mask = prop.collision_mask
	prop.request_hold(2, 20)
	var held_revision = prop.physics_revision
	check(prop.held and prop.holdId == 2 and shape.disabled, "host grants held prop to requester")
	prop.request_hold(3, 0)
	check(prop.holdId == 2, "second player cannot steal held prop")
	prop.request_release(3, Vector3.ZERO, Vector3.BACK, Vector3.ZERO, true)
	check(prop.held, "non-holder cannot release prop")
	prop.request_release(2, Vector3(100, 0, 0), Vector3.BACK, Vector3.ZERO, true)
	check(prop.held, "remote teleport throw rejected")
	prop.request_release(2, Vector3.ZERO, Vector3.BACK, Vector3(3, 0, 0), true)
	check(not prop.held and prop.holdId == 0, "throw releases ownership")
	check(prop.velocity == Vector3(3, 0, -39), "vanilla throw includes mass and player velocity exactly once")
	var stale_transform = Transform.IDENTITY
	stale_transform.origin = Vector3(5, 5, 5)
	prop.client_set_lerp_transform(1, stale_transform, held_revision)
	check(prop.lerp_transform.origin == Vector3.ZERO, "late carried pose cannot overwrite reliable release")
	check(prop.collision_layer == original_layer and prop.collision_mask == original_mask and not shape.disabled, "release restores original collision settings")
	prop.request_hold(2, 0)
	prop.request_release(2, Vector3.ZERO, Vector3.ZERO, Vector3(50, 0, 0), false)
	check(prop.velocity == Vector3.ZERO, "ordinary drop has vanilla zero carried velocity")
	for repeat in range(3):
		prop.sync_hold_state(1, 0, Transform.IDENTITY, Vector3.ZERO, false, false, prop.physics_revision)
	check(not prop.is_in_group("network_held_props"), "repeated release and settle updates safely leave held group")
	elevator_bridge.authority = false
	prop.set_notify_local_transform(true)
	prop.sync_settled_pose(1, Transform.IDENTITY, Vector3.ZERO, prop.physics_revision + 1)
	check(not prop.is_physics_processing(), "settled client prop suspends its physics callback")
	prop.transform_changes = 0
	for _frame in range(120):
		prop.step(1.0 / 60.0)
	check(prop.transform_changes == 0, "settled client prop does not rewrite its physics transform every frame")
	prop.set_notify_local_transform(false)
	prop.client_set_lerp_transform(1, Transform(Basis(), Vector3(1, 0, 0)), prop.physics_revision)
	check(prop.is_physics_processing(), "fresh movement wakes a settled client prop")
	prop.step(1.0)
	check(is_equal_approx(prop.translation.x, 1.0), "new client pose moves a settled prop without overshooting on slow frames")
	elevator_bridge.authority = true
	prop.free()
	elevator_bridge.actor.free()
	var revive_bridge = Bridge.new()
	revive_bridge.Multiplayer = multiplayer
	revive_bridge.SteamInit = parent
	revive_bridge.SteamLobby = lobby
	revive_bridge.multiplayer_mode = revive_bridge.MULTIPLAYER_TYPE.STEAM
	multiplayer.Players = Spatial.new()
	root.add_child(multiplayer.Players)
	var revive_targets = []
	for peer_id in [1, 2, 3]:
		var avatar = Spatial.new()
		avatar.name = str(peer_id)
		multiplayer.Players.add_child(avatar)
		avatar.set_script(load("res://MOD_CONTENT/CruS Online/multiplayer_player.gd"))
		avatar.Multiplayer = multiplayer
		avatar.NetworkBridge = revive_bridge
		avatar.set_process(false)
		avatar.set_physics_process(false)
		revive_targets.append(avatar)
	var latest_pose = Transform(Basis(), Vector3(8, 0, 0))
	revive_targets[1].NetworkBridge = elevator_bridge
	revive_targets[1]._update_puppet(2, latest_pose, [0.0, 0.0], 0.0)
	revive_targets[1].NetworkBridge = revive_bridge
	check(revive_targets[1].global_transform == latest_pose, "host collision pose uses newest client update without visual smoothing delay")
	Global.player = DamageReceiver.new()
	Global.player.bridge = revive_bridge
	root.add_child(Global.player)
	Global.player.translation = Vector3(20, 0, 0)
	revive_targets[0].translation = Vector3(200, 0, 0)
	revive_targets[1].translation = Vector3(21, 0, 0)
	multiplayer.died_players = [1]
	check(revive_targets[0].validate_network_action(2, 1, "_respawn_player", []), "client can revive dead host despite stale local puppet pose and death flag")
	multiplayer.died_players = [2]
	check(revive_targets[1].validate_network_action(1, 2, "_respawn_player", []), "host can revive client using actual local player position")
	revive_targets[2].translation = Vector3(22, 0, 0)
	check(revive_targets[1].validate_network_action(3, 2, "_respawn_player", []), "client can revive another client")
	multiplayer.died_players = [2, 3]
	check(not revive_targets[1].validate_network_action(3, 2, "_respawn_player", []), "dead helper cannot revive")
	multiplayer.died_players = [2]
	revive_targets[2].translation = Vector3(100, 0, 0)
	check(not revive_targets[1].validate_network_action(3, 2, "_respawn_player", []), "distant helper cannot revive")
	multiplayer.died_players = []
	check(not revive_targets[1].validate_network_action(1, 2, "_respawn_player", []), "living target cannot be revived")
	multiplayer.hostSettings.friendlyFire = false
	for avatar in revive_targets:
		avatar.canDamage = true
	var hit_args = [25, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 0, 2]
	check(not revive_targets[0].validate_network_action(2, 1, "_do_damage", hit_args), "friendly fire off rejects client shooting host")
	check(not revive_targets[2].validate_network_action(2, 3, "_do_damage", hit_args), "friendly fire off rejects client shooting client")
	hit_args[5] = 0
	check(revive_targets[1].validate_network_action(1, 2, "_do_damage", hit_args), "host simulated enemy damage still reaches clients")
	check(not revive_targets[0].validate_network_action(2, 1, "_do_damage", hit_args), "client cannot claim environmental damage to bypass friendly fire")
	var weapon_source = WeaponSource.new()
	var other_player_body = DamageReceiver.new()
	other_player_body.client = revive_targets[1]
	other_player_body.bridge = revive_bridge
	var npc_body = DamageReceiver.new()
	npc_body.bridge = revive_bridge
	revive_bridge.apply_damage(weapon_source, other_player_body, "damage", [10])
	check(other_player_body.health == 100, "friendly fire off prevents local weapon damaging another player")
	var grenade_source = Node.new()
	revive_bridge.inherit_damage_source(grenade_source, weapon_source)
	var explosion_source = Node.new()
	revive_bridge.inherit_damage_source(explosion_source, grenade_source)
	revive_bridge.apply_damage(explosion_source, other_player_body, "damage", [10])
	check(other_player_body.health == 100, "projectile explosion inherits shooter and cannot bypass friendly fire")
	revive_bridge.apply_damage(explosion_source, Global.player, "damage", [10])
	check(Global.player.health == 90 and Global.player.source_seen == 1, "own explosion still causes self damage")
	revive_bridge.apply_damage(explosion_source, npc_body, "damage", [10])
	check(npc_body.health == 90, "player can damage NPC with friendly fire disabled")
	weapon_source.player = false
	revive_bridge.apply_damage(weapon_source, other_player_body, "damage", [10])
	check(other_player_body.health == 90 and other_player_body.source_seen == 0, "NPC weapon damage remains environmental rather than host friendly fire")
	multiplayer.hostSettings.friendlyFire = true
	revive_bridge.apply_damage(explosion_source, other_player_body, "damage", [10])
	check(other_player_body.health == 80 and other_player_body.source_seen == 1, "friendly fire on restores player damage")
	check(revive_bridge.damage_source_context == 0, "damage attribution does not leak into later environmental damage")
	weapon_source.free()
	grenade_source.free()
	explosion_source.free()
	other_player_body.free()
	npc_body.free()
	var test_weapon_mesh = Spatial.new()
	revive_targets[1].add_child(test_weapon_mesh)
	test_weapon_mesh.add_child(Spatial.new())
	var shot_audio = AudioStreamPlayer3D.new()
	test_weapon_mesh.add_child(shot_audio)
	var flash_timer = Timer.new()
	flash_timer.name = "FlashBuffer"
	revive_targets[1].add_child(flash_timer)
	revive_targets[1].weaponsMesh = [test_weapon_mesh]
	revive_targets[1].shoot_commit(1, 1.5, 3)
	check(shot_audio.pitch_scale == 1.5 and not flash_timer.is_stopped(), "missing alternate shot sound falls back without out-of-bounds access")
	multiplayer.Players.free()
	Global.player.free()
	revive_bridge.free()
	var anim_enemy = load("res://MOD_CONTENT/CruS Online/entities/E_Grunt_Movement_New.gd").new()
	anim_enemy.anim_player = AnimationPlayer.new()
	anim_enemy.anim_player.add_animation("Idle", Animation.new())
	anim_enemy._configure_animations()
	anim_enemy.set_animation(1, "Attack", 1.0)
	check(not anim_enemy.has_anim_attack and anim_enemy.anim_player.get_animation("Idle").loop, "NPC without attack animation initializes and ignores missing animation")
	anim_enemy.anim_player.add_animation("Attack", Animation.new())
	anim_enemy._configure_animations()
	check(anim_enemy.has_anim_attack and anim_enemy.anim_player.get_animation("Attack").loop, "NPC attack animation remains enabled when present")
	anim_enemy.NetworkBridge = elevator_bridge
	anim_enemy.player = null
	anim_enemy.in_sight = true
	anim_enemy.track_player(0.016)
	check(not anim_enemy.in_sight, "missing enemy target clears previous visibility")
	var sight_actor = SightActor.new()
	root.add_child(sight_actor)
	sight_actor.aim_point = Spatial.new()
	sight_actor.add_child(sight_actor.aim_point)
	sight_actor.aim_point.translation.z = -5
	var sight_ray = SightRay.new()
	root.add_child(sight_ray)
	anim_enemy.player = sight_actor
	anim_enemy.player_ray = sight_ray
	anim_enemy.in_sight = true
	anim_enemy.track_player(0.016)
	check(sight_ray.refreshed == 1 and not anim_enemy.in_sight, "fresh empty ray clears stale enemy line of sight")
	var sight_wall = StaticBody.new()
	root.add_child(sight_wall)
	sight_ray.collider = sight_wall
	anim_enemy.in_sight = true
	anim_enemy.track_player(0.016)
	check(sight_ray.refreshed == 2 and not anim_enemy.in_sight, "sight_wall blocks selected target even after earlier visibility")
	anim_enemy.dead = true
	anim_enemy.track_player(0.016)
	check(sight_ray.refreshed == 2 and not anim_enemy.in_sight, "dead enemy cannot acquire a firing target")
	sight_wall.free()
	sight_ray.free()
	sight_actor.free()
	anim_enemy.anim_player.free()
	anim_enemy.free()
	var flash_soul = FlashSoulFixture.new()
	root.add_child(flash_soul)
	var flash_body = FlashBodyFixture.new()
	flash_soul.add_child(flash_body)
	flash_body.muzzleflash = Spatial.new()
	flash_body.add_child(flash_body.muzzleflash)
	var flash_rotation = Spatial.new()
	flash_body.add_child(flash_rotation)
	var flash_weapon = Spatial.new()
	flash_rotation.add_child(flash_weapon)
	flash_weapon.set_script(load("res://MOD_CONTENT/CruS Online/remaped/weapon.gd"))
	flash_weapon.set_process(false)
	flash_weapon.set_physics_process(false)
	var flash_sound = AudioStreamPlayer.new()
	flash_weapon.add_child(flash_sound)
	flash_weapon.audio = [[flash_sound], null]
	flash_weapon.npc_muzzleflash(1, 0)
	check(flash_body.muzzleflash.visible and not flash_weapon._npc_flash_timer.is_stopped(), "NPC flash schedules its own expiry with physics processing disabled and array audio")
	flash_body.dead = true
	flash_weapon.npc_muzzleflash(1, 0)
	check(not flash_body.muzzleflash.visible and flash_weapon._npc_flash_timer.is_stopped(), "late shot cannot leave a muzzle flash on a corpse")
	flash_soul.free()
	var collision_owner = CollisionOwnerFixture.new()
	collision_owner.name = "2"
	collision_owner.NetworkBridge = elevator_bridge
	root.add_child(collision_owner)
	var collision_puppet = Spatial.new()
	collision_owner.add_child(collision_puppet)
	var collision_proxy = load("res://MOD_CONTENT/CruS Online/PlayerCollisionProxy.gd").new()
	collision_puppet.add_child(collision_proxy)
	check(is_equal_approx(collision_proxy.collision_shape.shape.extents.y, 0.903937), "remote standing gameplay collider matches the original player")
	collision_owner.playerCrouch = true
	collision_proxy.update_stance()
	check(is_equal_approx(collision_proxy.collision_shape.shape.extents.y, 0.414648), "remote crouch updates gameplay collision without waiting for visual animation")
	collision_owner.free()
	var counter = ObjectiveCounter.new()
	var enemy = load("res://MOD_CONTENT/CruS Online/entities/EnemyHandler.gd").new()
	enemy.glob = counter
	enemy.NetworkBridge = elevator_bridge
	enemy.objective = true
	enemy.enabled = false
	check(not enemy._register_objective() and counter.objectives == 0, "rejected Chaos spawn cannot register phantom objective")
	enemy.enabled = true
	check(enemy._register_objective() and counter.objectives == 1, "active host NPC registers objective")
	check(not enemy._register_objective() and counter.objectives == 1, "objective registration idempotent")
	enemy._complete_objective()
	enemy._complete_objective()
	check(counter.objectives == 0 and counter.removals == 1, "DNA/death cannot remove same objective twice")
	enemy.objective_registered = false
	counter.CURRENT_LEVEL = 18
	check(not enemy._register_objective() and counter.objectives == 0, "Trauma Loop completion is not blocked by NPC targets")
	enemy.free()
	Global.UI = NotifyFixture.new()
	root.add_child(Global.UI)
	multiplayer.players = {1: {}, 2: {}}
	var mission_exit = ExitFixture.new()
	root.add_child(mission_exit)
	mission_exit.set_physics_process(false)
	mission_exit.presence = [1, 2]
	check(not mission_exit._evaluate_exit(), "unfinished objectives block exit")
	Global.objective_complete = true
	check(mission_exit._evaluate_exit() and mission_exit.exiting, "final objective while already inside starts exit")
	check(mission_exit.exitTimer.is_stopped(), "extraction is queued immediately without a countdown")
	mission_exit.presence = [1]
	check(not mission_exit._evaluate_exit() and mission_exit.exitTimer.is_stopped(), "leaving cancels countdown")
	multiplayer.died_players = [2]
	check(mission_exit._evaluate_exit(), "dead player does not prevent surviving player exfil")
	multiplayer.died_players = [1, 2]
	check(not mission_exit._evaluate_exit(), "all dead cannot complete mission")
	multiplayer.died_players = []
	multiplayer.Flow = WaitingFlowFixture.new()
	multiplayer.Flow.ending = "res://Cutscenes/CutsceneEnd3.tscn"
	check(mission_exit._evaluate_exit(), "one living player can trigger an ending while another stays outside")
	multiplayer.Flow.ending = ""
	multiplayer.Flow.waiting_peers = [2]
	check(mission_exit._evaluate_exit(), "players waiting in menus do not block mission extraction")
	multiplayer.Flow.free()
	multiplayer.Flow = null
	multiplayer.players.erase(2)
	check(mission_exit._evaluate_exit(), "disconnected player no longer blocks exit")
	mission_exit.presence = []
	mission_exit.exit_to_menu()
	check(multiplayer.completions == 0, "timeout rechecks actual presence")
	mission_exit.presence = [1]
	mission_exit.exit_to_menu()
	mission_exit.exit_to_menu()
	check(multiplayer.completions == 1, "mission transition commits once")
	mission_exit.free()
	Global.UI.free()

	Global.menu = MenuStateFixture.new()
	var menu_exit = Node.new()
	root.add_child(menu_exit)
	menu_exit.set_script(MenuExitFixture)
	menu_exit.NetworkBridge = elevator_bridge
	menu_exit.players = {1: {}, 2: {}}
	menu_exit.Flow = WaitingFlowFixture.new()
	menu_exit.request_menu_exit(2, true)
	menu_exit.request_menu_exit(1, false)
	check(menu_exit.destinations == [[false, false]] and menu_exit.Flow.requests == [[2, true]], "client exits wait locally while host exits move the lobby")
	menu_exit.request_menu_exit(99, true)
	menu_exit.request_menu_exit(2, "invalid")
	elevator_bridge.authority = false
	menu_exit.request_menu_exit(2, true)
	elevator_bridge.authority = true
	Global.menu.in_game = false
	menu_exit.request_menu_exit(2, true)
	check(menu_exit.destinations.size() == 1 and menu_exit.Flow.requests.size() == 1, "group exits reject outsiders, malformed requests, non-host execution and duplicate menu transitions")
	Global.menu.free()
	menu_exit.Flow.free()
	menu_exit.free()

	var coordinator = Node.new()
	root.add_child(coordinator)
	coordinator.set_script(load("res://MOD_CONTENT/CruS Online/multiplayer.gd"))
	coordinator.NetworkBridge = elevator_bridge
	coordinator.DeathScreen = NotifyFixture.new()
	var restart_timer = Timer.new()
	restart_timer.name = "RestartTimer"
	coordinator.add_child(restart_timer)
	coordinator.players = {1: {}, 2: {}}
	coordinator.config.friendlyFire = false
	coordinator.apply_host_settings()
	check(not coordinator.hostSettings.friendlyFire, "host option applies to live session settings")
	coordinator.sync_host_settings(1, {"friendlyFire": true})
	check(coordinator.hostSettings.friendlyFire, "client applies host friendly fire setting")
	coordinator.sync_host_settings(2, {"friendlyFire": false})
	check(coordinator.hostSettings.friendlyFire, "non-host cannot change friendly fire setting")
	coordinator.hostSettings.canRespawn = true
	coordinator._player_died(1)
	check(coordinator.DeathScreen.wipes == 0, "one player dying does not lower difficulty")
	coordinator._player_died(2)
	check(coordinator.DeathScreen.wipes == 1, "last player dying applies difficulty loss once")
	coordinator.apply_team_wipe(1)
	check(coordinator.DeathScreen.wipes == 1, "duplicate team wipe cannot lower difficulty twice")
	check(coordinator.died_players.size() == 2 and restart_timer.is_stopped(), "manual respawn tracks deaths without automatic restart")
	coordinator._player_respawn(1)
	coordinator.hostSettings.canRespawn = false
	coordinator._player_died(1)
	check(not restart_timer.is_stopped(), "all dead starts restart when manual respawn disabled")
	check(coordinator.DeathScreen.wipes == 2, "a new team wipe counts after someone respawns")
	coordinator._player_respawn(2)
	check(restart_timer.is_stopped() and not coordinator.died_players.has(2), "revive cancels pending restart and clears dead membership")
	var life_puppet = LifePuppet.new()
	life_puppet.name = "3"
	root.add_child(life_puppet)
	coordinator.players[3] = {"puppet": life_puppet}
	coordinator._player_died(3)
	check(life_puppet.death and elevator_bridge.events.back()[0] == "sync_player_life", "third player death is applied locally and broadcast to every peer")
	coordinator._player_respawn(3)
	check(not life_puppet.death and life_puppet.resets == 1 and elevator_bridge.events.back()[1] == [3, false], "third player revive clears pose and broadcasts alive state")
	var target_body = Spatial.new()
	life_puppet.add_child(target_body)
	var targeting = load("res://MOD_CONTENT/CruS Online/EnemyTargeting.gd")
	check(targeting.alive(target_body, null, 1, []), "AI can select a living third player")
	check(not targeting.alive(target_body, null, 3, []), "AI ignores the local player's duplicate puppet")
	check(not targeting.alive(target_body, null, 1, [3]), "AI ignores authoritative dead players")
	life_puppet.death = true
	check(not targeting.alive(target_body, null, 1, []), "AI ignores a visibly dead puppet")
	var hitbox = StaticBody.new()
	target_body.add_child(hitbox)
	check(targeting.matches(hitbox, target_body) and not targeting.matches(coordinator, target_body), "target matching follows the selected player's hierarchy")
	life_puppet.free()
	coordinator._player_died(999)
	check(not coordinator.died_players.has(999), "nonmember death ignored")
	Global.UI = NotifyFixture.new()
	coordinator.notify_host_difficulty(1, "Host difficulty: Hope Eradicated + Chaos")
	check(Global.UI.messages == ["Host difficulty: Hope Eradicated + Chaos"], "difficulty goes to gameplay notifications")
	elevator_bridge.online = false
	coordinator.notify_host_difficulty(1, "stale announcement")
	check(Global.UI.messages.size() == 1, "offline play ignores host announcements")
	Global.UI.free()
	Global.menu = Control.new()
	root.add_child(Global.menu)
	coordinator.Menu = Control.new()
	coordinator.add_child(coordinator.Menu)
	coordinator.Menu.show()
	coordinator.Menu.set_process_input(true)
	var sync_screen = Control.new()
	sync_screen.name = "SyncLoad"
	coordinator.add_child(sync_screen)
	sync_screen.show()
	check(coordinator.game_init("offline://level"), "solo mission start succeeds without hosting")
	check(Global.last_scene == "offline://level", "solo start loads selected level")
	check(not coordinator.Menu.visible and not coordinator.Menu.is_processing_input(), "solo disables multiplayer pause menu")
	check(Global.menu.is_processing_input() and not sync_screen.visible, "solo uses vanilla menu without sync screen")
	coordinator.player_scene_loaded = false
	coordinator._scene_loaded()
	check(coordinator.player_scene_loaded and not get_tree().paused and not sync_screen.visible, "solo level load never waits for other players")
	Global.menu.free()
	elevator_bridge.online = true
	coordinator.DeathScreen.free()
	coordinator.free()
	var regular_door = KinematicBody.new()
	root.add_child(regular_door)
	regular_door.set_script(load("res://MOD_CONTENT/CruS Online/remaped/Door.gd"))
	regular_door.NetworkBridge = elevator_bridge
	elevator_bridge.authority = true
	regular_door.network_use(2)
	var moving_pose_revision = regular_door.pose_revision
	regular_door._physics_process(10.0)
	check(regular_door.stop and is_equal_approx(abs(regular_door.rotation.y), PI / 2), "ordinary door clamps a long frame to its final angle")
	check(elevator_bridge.events.back()[0] == "sync_door_pose", "ordinary door reliably publishes final pose")
	var stopped_pose = regular_door.global_transform
	regular_door._set_transform(1, Transform.IDENTITY, moving_pose_revision)
	check(regular_door.global_transform == stopped_pose, "ordinary door ignores snapshots from before it stopped")
	elevator_bridge.authority = false
	regular_door.network_damage(2, 999, Vector3.UP, Vector3.ZERO, Vector3.ZERO)
	check(regular_door.visible and not regular_door.isDestroyed and regular_door.door_health == 100, "client door hit waits for host instead of hiding and later reappearing")
	regular_door.remove_on_ready(1)
	check(regular_door.isDestroyed and not regular_door.visible, "confirmed destruction stays hidden")
	elevator_bridge.authority = true
	regular_door.free()
	for sliding_name in ["down_door", "down_switch_door"]:
		var sliding = KinematicBody.new()
		root.add_child(sliding)
		sliding.set_script(load("res://MOD_CONTENT/CruS Online/remaped/" + sliding_name + ".gd"))
		sliding.NetworkBridge = elevator_bridge
		if sliding_name == "down_door":
			sliding.timer = Timer.new()
			sliding.add_child(sliding.timer)
		var prior_events = elevator_bridge.events.size()
		sliding._physics_process(1.0)
		check(elevator_bridge.events.size() == prior_events, "stopped sliding door sends no redundant updates")
		sliding.switch_use()
		check(not sliding.stop, "vanilla no-argument switch activates a sliding platform")
		sliding.sync_door_pose(1, Transform(Basis(), Vector3(0, 4, 0)), 2)
		sliding._set_transform(1, Transform.IDENTITY, 1)
		check(sliding.translation.y == 4, "sliding door ignores stale movement after final pose")
		sliding.free()
	var spiritual_states = [
		{"soul_intact": true, "husk_mode": false, "hope_discarded": false},
		{"soul_intact": false, "husk_mode": true, "hope_discarded": false},
		{"soul_intact": false, "husk_mode": false, "hope_discarded": true}]
	elevator_bridge.actor = Spatial.new()
	root.add_child(elevator_bridge.actor)
	for index in range(2):
		var door = KinematicBody.new()
		root.add_child(door)
		var door_name = "Divine_Door" if index == 0 else "Profane_Door"
		door.set_script(load("res://MOD_CONTENT/CruS Online/remaped/" + door_name + ".gd"))
		door.NetworkBridge = elevator_bridge
		door.set_physics_process(false)
		door.request_use(2, spiritual_states[2])
		check(door.stop and not door.open, "wrong player state cannot open " + door_name)
		door.request_use(999, spiritual_states[index])
		check(door.stop, "unknown requester rejected by " + door_name)
		elevator_bridge.actor.translation.x = 20
		door.request_use(2, spiritual_states[index])
		check(door.stop, "distant requester rejected by " + door_name)
		elevator_bridge.actor.translation.x = 0
		door.request_use(2, {"soul_intact": true, "husk_mode": true, "hope_discarded": false})
		check(door.stop, "contradictory spiritual state rejected")
		door.request_use(2, spiritual_states[index])
		check(not door.stop and door.open, "eligible remote player opens " + door_name)
		var moving_revision = door.door_revision
		door._physics_process(10.0)
		check(door.stop and is_equal_approx(abs(door.rotation.y), PI / 2), "door settles at 90 degrees even on long frame")
		check(elevator_bridge.events.back()[0] == "sync_door", "door publishes reliable final pose")
		var final_pose = door.global_transform
		door._set_transform(1, Transform.IDENTITY, moving_revision)
		check(door.global_transform == final_pose, "late moving snapshot cannot overwrite stopped door")
		elevator_bridge.authority = false
		door.request_use(2, spiritual_states[index])
		check(door.stop, "client cannot execute authoritative door toggle")
		door.sync_door(1, Transform.IDENTITY, false, true, door.door_revision + 1)
		check(door.global_transform == Transform.IDENTITY and not door.open, "client applies reliable door state")
		elevator_bridge.authority = true
		Global.soul_intact = index == 0
		Global.husk_mode = index == 1
		Global.hope_discarded = false
		door.player_use()
		check(door.open and not door.stop, "vanilla no-argument interaction publishes current player flags")
		check(not door.has_method("door_use"), "unchecked legacy door toggle removed")
		door.free()
	var terror_parent = Spatial.new()
	root.add_child(terror_parent)
	var terror = KinematicBody.new()
	terror_parent.add_child(terror)
	terror.set_script(load("res://MOD_CONTENT/CruS Online/remaped/Terror_Door.gd"))
	terror.NetworkBridge = elevator_bridge
	var gib_template = GibFixture.new()
	gib_template.name = "Gib"
	var gib_scene = PackedScene.new()
	gib_scene.pack(gib_template)
	gib_template.free()
	terror.GIB = gib_scene
	var door_policy = load("res://MOD_CONTENT/CruS Online/SpiritualDoorPolicy.gd")
	check(not door_policy.allows({"soul_intact": "true", "husk_mode": false, "hope_discarded": false}, "soul_intact", Vector3.ZERO, Vector3.ZERO), "spiritual flags require booleans")
	check(not door_policy.allows({"soul_intact": false, "husk_mode": false, "hope_discarded": false}, "soul_intact", Vector3.ZERO, Vector3.ZERO), "Flesh Automaton does not inherit host Divine access")
	terror.request_use(2, spiritual_states[0])
	check(not terror.isDestroyed and terror_parent.get_child_count() == 1, "terror door rejects divine player")
	terror.request_use(2, spiritual_states[2])
	check(terror.isDestroyed and terror_parent.get_child_count() == 11 and terror.collision_layer == 0, "remote Hope player destroys terror door and spawns ten gibs")
	terror.request_use(2, spiritual_states[2])
	check(terror_parent.get_child_count() == 11, "repeat terror request does not duplicate gibs")
	terror._get_state(3)
	check(elevator_bridge.events.back()[0] == "remove_on_ready" and elevator_bridge.events.back()[2] == 3, "late terror state request receives removal")
	terror.spawn_gib(1, "ReplicatedGib", Transform.IDENTITY, Vector3.UP)
	terror.spawn_gib(1, "ReplicatedGib", Transform.IDENTITY, Vector3.UP)
	check(terror_parent.get_child_count() == 12 and terror_parent.get_node("ReplicatedGib").velocity == Vector3.UP, "replicated gib initial state and duplicate rejection")
	terror_parent.free()


	var cancer_scene = PackedScene.new()
	var cancer_template = StaticBody.new()
	for visual in [MeshInstance.new(), AudioStreamPlayer3D.new()]:
		visual.name = "MeshInstance" if visual is MeshInstance else "Audio"
		cancer_template.add_child(visual)
		visual.owner = cancer_template
	cancer_scene.pack(cancer_template)
	cancer_template.free()
	var growth_host = Spatial.new()
	growth_host.name = "CancerReplication"
	multiplayer.add_child(growth_host)
	growth_host.set_script(load("res://MOD_CONTENT/CruS Online/CancerReplication.gd"))
	growth_host.NetworkBridge = elevator_bridge
	growth_host.segment_scene = cancer_scene
	growth_host.gib_scenes = [gib_scene]
	growth_host._ready()
	growth_host.set_process(false)
	var growth_client = Spatial.new()
	root.add_child(growth_client)
	growth_client.set_script(load("res://MOD_CONTENT/CruS Online/CancerReplication.gd"))
	var client_bridge = ElevatorBridge.new()
	client_bridge.authority = false
	growth_client.NetworkBridge = client_bridge
	growth_client.segment_scene = cancer_scene
	growth_client.gib_scenes = [gib_scene]
	growth_client.set_process(false)
	var cancer_npc = CancerNpcFixture.new()
	root.add_child(cancer_npc)
	cancer_npc.armor = 1
	check(not growth_host.convert_npc(cancer_npc, Vector3.ZERO), "DNA preserves armor immunity")
	cancer_npc.armor = 0
	cancer_npc.cancer_immunity = true
	check(not growth_host.convert_npc(cancer_npc, Vector3.ZERO), "DNA preserves explicit cancer immunity")
	cancer_npc.cancer_immunity = false
	elevator_bridge.events.clear()
	var cancer_hitbox = KinematicBody.new()
	root.add_child(cancer_hitbox)
	cancer_hitbox.set_script(load("res://MOD_CONTENT/CruS Online/entities/Enemy_Torso.gd"))
	cancer_hitbox.NetworkBridge = elevator_bridge
	cancer_hitbox.soul = cancer_npc
	cancer_hitbox.request_cancer(999, 0)
	check(not cancer_npc.dead, "unknown peer cannot request NPC DNA conversion")
	cancer_hitbox.request_cancer(2, -1)
	check(not cancer_npc.dead, "previous-scene DNA hitbox request ignored")
	cancer_hitbox.request_cancer(2, 0)
	check(cancer_npc.dead, "actual NPC hitbox accepts eligible client DNA request")
	cancer_hitbox.free()
	check(cancer_npc.dead and cancer_npc.is_queued_for_deletion() and cancer_npc.objective_removals == 1, "DNA removes NPC and objective once instead of hiding live AI")
	check(not growth_host.convert_npc(cancer_npc, Vector3.ZERO), "repeated DNA hit cannot convert NPC twice")
	for frame in range(12):
		growth_host._process(0.016)
	check(growth_host.entities.size() == 66 and growth_host.growth.empty(), "six DNA roots grow to vanilla eleven-segment limit")
	for event in elevator_bridge.events:
		var values = bytes2var(var2bytes(event[1]))
		values.push_front(1)
		growth_client.callv(event[0], values)
	check(growth_client.entities.size() == 66 and growth_client.growth.empty(), "replica receives all segments without running local random growth")
	for identifier in growth_host.entities:
		var host_segment = growth_host.entities[identifier]
		var client_segment = growth_client.entities[identifier]
		check(host_segment.global_transform.is_equal_approx(client_segment.global_transform), "replica DNA pose matches host")
		check(host_segment.get_node("MeshInstance").scale.is_equal_approx(client_segment.get_node("MeshInstance").scale), "replica DNA mesh scale matches host")
	var root_segment_id = growth_host.get_child(0).entity_id
	growth_host.request_damage(999, 0, root_segment_id, 1, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	growth_host.request_damage(2, -1, root_segment_id, 1, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	check(growth_host.hits.empty(), "unknown sender and previous-scene DNA damage rejected")
	elevator_bridge.events.clear()
	growth_host.request_damage(2, 0, root_segment_id, 1, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	for frame in range(24):
		growth_host._process(0.016)
	check(growth_host.entities.size() < 66, "remote shot propagates to chain tip and removes segments")
	for event in elevator_bridge.events:
		var values = bytes2var(var2bytes(event[1]))
		values.push_front(1)
		growth_client.callv(event[0], values)
	check(growth_client.entities.size() == growth_host.entities.size(), "replica chain damage removes same segments")
	elevator_bridge.events.clear()
	root_segment_id = 2
	var wall = StaticBody.new()
	wall.collision_layer = 1
	growth_host.entities[root_segment_id]._on_Cancerball_body_entered(wall)
	wall.free()
	for event in elevator_bridge.events:
		var values = event[1].duplicate()
		values.push_front(1)
		growth_client.callv(event[0], values)
	check(not growth_host.entities.has(root_segment_id) and not growth_client.entities.has(root_segment_id), "host wall collision removes replicated subtree")
	var next_cancer_id = growth_host.next_id
	growth_host.reset(1)
	growth_client.reset(1)
	check(growth_host.entities.empty() and growth_host.get_child_count() == 0 and growth_client.entities.empty(), "mission reset releases cancer registry and scene objects")
	growth_client.spawn_segment(1, 0, next_cancer_id, 0, Transform.IDENTITY, Vector3.UP, 1, Vector3.ONE)
	check(growth_client.entities.empty(), "old scene spawn cannot repopulate cancer registry")
	check(growth_host.next_id == next_cancer_id, "cancer IDs are not recycled on mission reset")
	growth_client.spawn_segment(1, 1, next_cancer_id, 0, Transform.IDENTITY, Vector3.UP, 1, Vector3.ONE)
	growth_client.remove_segment(1, 1, next_cancer_id)
	growth_client.spawn_segment(1, 1, next_cancer_id, 0, Transform.IDENTITY, Vector3.UP, 1, Vector3.ONE)
	check(growth_client.entities.empty(), "replayed spawn cannot resurrect removed cancer segment")
	growth_host.free()
	growth_client.free()
	client_bridge.free()
	elevator_bridge.actor.free()
	elevator_bridge.free()
	var profiles = load("res://MOD_CONTENT/CruS Online/ProfileStore.gd").new()
	profiles.directory_path = "res://profile_fixture/nested/settings"
	check(profiles.save_data("player.save", {"nickname": "First", "skinPath": "skin_a"}), "profile creates nested directory")
	check(profiles.save_data("player.save", {"nickname": "Second", "skinPath": "skin_b"}), "profile replaces existing file")
	check(profiles.load_data("player.save").nickname == "Second", "profile values survive reopen")
	var corrupt = File.new()
	corrupt.open(profiles.directory_path.plus_file("player.save"), File.WRITE)
	corrupt.store_string("[]")
	corrupt.close()
	check(profiles.load_data("player.save").nickname == "First", "corrupt primary recovers last valid backup")
	var merged = profiles.merge_defaults({"nickname": "Default", "color": "ff00ff", "tickRate": 3}, {"nickname": "Saved", "tickRate": "bad"})
	check(merged.nickname == "Saved" and merged.color == "ff00ff" and merged.tickRate == 3, "profile schema upgrades retain valid values")
	check(not profiles.save_data("../savegame.save", {}), "profile store cannot address vanilla save")
	for collection in ["playerNameImage", "playerSkins"]:
		var selector = load("res://" + collection + ".gd").new()
		selector.set(collection, [["First", "path_a", null], ["Second", "path_b", null]])
		var items = ItemList.new()
		items.name = "ItemList"
		selector.add_child(items)
		var texture = TextureRect.new()
		texture.name = "TextureRect"
		selector.add_child(texture)
		root.add_child(selector)
		selector.set_texture("path_b")
		check(selector.get_texture() == "path_b" and selector.selected == 1, "restored selector saves same skin/image")
		selector.free()
	var viewport = Viewport.new()
	viewport.size = Vector2(2560, 1440)
	root.add_child(viewport)
	var ui_bridge = Node.new()
	ui_bridge.name = "NetworkBridge"
	viewport.add_child(ui_bridge)
	var menu = load("res://MOD_CONTENT/CruS Online/Menu.gd").new()
	viewport.add_child(menu)
	check(menu.rect_size == Vector2(1280, 720) and menu.rect_scale == Vector2(2, 2), "1440p menu scales logical canvas once")
	var panel = load("res://MOD_CONTENT/CruS Online/FloatingPanel.gd").new()
	menu.add_child(panel)
	panel.rect_size = Vector2(620, 430)
	panel.rect_scale = Vector2(0.5, 0.5)
	panel.rect_position = Vector2(2000, 2000)
	panel.fit_in_parent()
	check(panel.rect_position.x + panel.rect_size.x * panel.rect_scale.x <= 1280 and panel.rect_position.y + panel.rect_size.y * panel.rect_scale.y <= 720, "dragged panels remain inside menu")
	viewport.size = Vector2(3440, 1440)
	menu._layout_menu()
	check(menu.rect_position == Vector2(440, 0), "ultrawide layout centered without stretching")
	viewport.free()
	var rope_scene = PackedScene.new()
	var rope_template = Spatial.new()
	rope_scene.pack(rope_template)
	rope_template.free()
	var anchor = Position3D.new()
	root.add_child(anchor)
	anchor.translation = Vector3(2, 0, 0)
	for local in [true, false]:
		var rope_player = KinematicBody.new() if local else Spatial.new()
		root.add_child(rope_player)
		rope_player.set_script(load("res://MOD_CONTENT/CruS Online/" + ("remaped/Player.gd" if local else "multiplayer_player.gd")))
		rope_player.grapple_orb = rope_scene
		rope_player.grapple_orbs = []
		if local:
			rope_player.playerPuppet = GrappleReceiver.new()
		else:
			rope_player.grapple_point = anchor
			rope_player.grapple_start_point = rope_player
			rope_player.grapple_pos = anchor.translation
		for frame in range(3):
			if local:
				rope_player.grapple(anchor)
			else:
				rope_player.set_grapple_orbs()
		check(rope_player.grapple_orbs.size() == 8, "local and remote rope converge on four orbs per unit")
		for index in range(8):
			check(rope_player.grapple_orbs[index].global_transform.origin.is_equal_approx(Vector3(index / 4.0, 0, 0)), "grapple orb spacing stays unchanged")

		for removed in range(5):
			rope_player.grapple_orbs.pop_back().free()
		anchor.translation = Vector3.ZERO
		if local:
			rope_player.grapple(anchor)
		else:
			rope_player.grapple_pos = Vector3.ZERO
			rope_player.set_grapple_orbs()
		check(rope_player.grapple_orbs.empty(), "short rope cleanup removes only the orbs that exist")
		rope_player.free()
		anchor.translation = Vector3(2, 0, 0)
	anchor.free()
	var implant_player = KinematicBody.new()
	root.add_child(implant_player)
	implant_player.set_script(load("res://MOD_CONTENT/CruS Online/remaped/Player.gd"))
	implant_player.GLOBAL = Global
	implant_player.weapon = {"weapon1": null, "weapon2": null}
	implant_player.UI = NotifyFixture.new()
	implant_player.add_child(implant_player.UI)
	implant_player.terrorsuit = Control.new()
	implant_player.add_child(implant_player.terrorsuit)
	var night_vision = Control.new()
	night_vision.name = "NV"
	implant_player.add_child(night_vision)
	var footstep = AudioStreamPlayer.new()
	footstep.name = "Foot_Step"
	implant_player.add_child(footstep)
	implant_player.orbWalkSound = AudioStreamSample.new()
	implant_player.playerWalkSound = AudioStreamSample.new()
	var screen = ColorRect.new()
	implant_player.add_child(screen)
	var vision_shader = Shader.new()
	vision_shader.code = "shader_type canvas_item; uniform bool scope = false; uniform bool nightmare_vision = false; uniform bool holy_mode = false;"
	screen.material = ShaderMaterial.new()
	screen.material.shader = vision_shader
	implant_player.shader_screen = screen
	var empty_implant = {"speed_bonus": 0.0, "jump_bonus": 0.0, "armor": 1.0,
		"nightmare": false, "nightvision": false, "holy": false, "radio": false,
		"orbsuit": false, "terror": false, "toxic_shield": false}
	Global.implants = {"head_implant": empty_implant.duplicate(), "torso_implant": empty_implant.duplicate(),
		"arm_implant": empty_implant.duplicate(), "leg_implant": empty_implant.duplicate(), "empty_implant": empty_implant}
	Global.music = AudioStreamPlayer.new()
	implant_player.add_child(Global.music)
	Global.husk_mode = true
	Global.death = true
	Global.implants.torso_implant.orbsuit = true
	Global.implants.torso_implant.armor = 0.6
	implant_player.update_implants()
	check(is_equal_approx(implant_player.speed_bonus, 1.35) and implant_player.health == 200 and implant_player.hazmat, "Golem refresh keeps suit and personal-state bonuses")
	check(is_equal_approx(implant_player._implant_speed_bonus(), implant_player.speed_bonus), "startup and respawn use same implant speed calculation")
	Global.implants.head_implant.nightmare = true
	implant_player.update_implants()
	check(night_vision.visible and screen.material.get_shader_param("nightmare_vision"), "nightmare vision enables on implant refresh")
	Global.implants.head_implant.nightmare = false
	Global.implants.head_implant.nightvision = true
	implant_player.update_implants()
	check(night_vision.visible and not screen.material.get_shader_param("nightmare_vision") and screen.material.get_shader_param("scope"), "switching to night vision clears nightmare without losing scope")
	Global.implants.torso_implant = empty_implant.duplicate()
	Global.implants.head_implant = empty_implant.duplicate()
	implant_player.update_implants()
	check(not implant_player.orb and not implant_player.hazmat and footstep.stream == implant_player.playerWalkSound, "removing Golem restores normal sound and protection")
	check(not night_vision.visible and not screen.material.get_shader_param("scope"), "removing vision implant clears its effects")
	Global.menu = Node.new()
	implant_player.add_child(Global.menu)
	var character_menu = Node.new()
	character_menu.name = "Character_Menu"
	Global.menu.add_child(character_menu)
	var character_controls = ImplantMenuFixture.new()
	character_controls.name = "Character_Container"
	character_menu.add_child(character_controls)
	Global.CURRENT_LEVEL = 18
	Global.LEVEL_AMBIENCE.resize(19)
	Global.implants.leg_implant = empty_implant.duplicate()
	Global.implants.leg_implant.speed_bonus = 10
	Global.implants.leg_implant.toxic_shield = true
	Global.implants.leg_implant.armor = 0.1
	implant_player.update_implants()
	check(is_equal_approx(implant_player.speed_bonus, 0.35) and implant_player.armor == 1 and not implant_player.hazmat, "stripped implants cannot leave old speed armor or protection behind")
	implant_player.free()

	net.connect("host_left", self, "record_host_departure")
	net._my_steam_id = 2
	net._migrate_host(1, 3)
	check(host_departures == 1, "Steam owner change ends the session instead of migrating broken world authority")
	net._my_steam_id = 2
	lobby.lobby_owner = 1
	net._reset_session()
	net._init_joined_lobby(10)
	check(net.get_server_steam_id() == 1 and net._peers.has(2), "joining seeds peers without waiting for a fresh native session callback")
	check(parent.Steam.sent.back()[1][0] == net.PACKET_TYPE.HANDSHAKE_REPLY, "join starts handshake proactively")
	var joined_peer = net._peers[2]
	net._init_joined_lobby(10)
	check(net._peers[2] == joined_peer, "duplicate lobby callback preserves the current connection")
	net._close_p2p_session(2)
	check(net._peers.empty() and net._server_steam_id == 0 and parent.Steam.closed.has(1), "leave clears peers and closes the old native session")
	lobby.lobby_owner = 3
	net._init_joined_lobby(11)
	check(net.get_server_steam_id() == 3 and not net._peers.has(1), "joining a different host does not reuse stale peer state")
	var packet = PoolByteArray([net.PACKET_TYPE.HANDSHAKE])
	packet.append_array(var2bytes(net.PROTOCOL_VERSION))
	net._handle_packet(3, packet)
	check(parent.Steam.sent.back()[0] == 3 and parent.Steam.sent.back()[1][0] == net.PACKET_TYPE.HANDSHAKE_REPLY, "rejoined client responds to new host handshake")
	net._init_p2p_host(12)
	net._init_p2p_session(2)
	check(net.is_server() and net._peers[2].connected, "local lobby-entered event cannot turn the host into an unconnected client")
	lobby.active = false
	net._on_p2p_session_request(3)
	check(parent.Steam.closed.back() == 3, "late session request after leaving is closed instead of left pending")
	lobby.active = true
	lobby.lobby_owner = 1
	var join_manager = Node.new()
	root.add_child(join_manager)
	join_manager.set_script(load("res://MOD_CONTENT/CruS Online/SteamLobby.gd"))
	join_manager.SteamInit = parent
	join_manager.join_lobby(10)
	join_manager.join_lobby(10)
	check(parent.Steam.joins == [10], "duplicate invite paths issue only one native join")
	join_manager.leave_lobby()
	join_manager.join_lobby(10)
	check(parent.Steam.joins == [10, 10], "leaving clears pending join so same lobby can be joined again")
	join_manager.free()
	print("TRANSPORT_TEST_RESULT failures=", failures)
	get_tree().quit(1 if failures else 0)
