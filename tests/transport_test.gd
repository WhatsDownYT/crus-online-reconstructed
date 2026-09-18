extends Node

const Network = preload("res://MOD_CONTENT/CruS Online/SteamNetwork.gd")
const Bridge = preload("res://MOD_CONTENT/CruS Online/NetworkBridge.gd")
const Policy = preload("res://MOD_CONTENT/CruS Online/PlayerActionPolicy.gd")
var failures = 0

class MultiplayerFixture:
	extends Node
	var players = {1: {}, 2: {}, 3: {}}
	var died_players = []
	var Players
	var completions = 0
	func goto_menu_host(_complete = false):
		completions += 1

class NotifyFixture:
	extends Control
	func notify(_text, _color):
		pass
	func set_death_label():
		pass

class ObjectiveCounter:
	extends Reference
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
	const P2P_SEND_RELIABLE = 2
	var incoming = {0: [], 1: []}
	var sent = []
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
	enum PERMISSION {SERVER, ALL}
	var authority = true
	var net
	var events = []
	var actor
	func get_id():
		return 1
	func request_sender(id):
		return 1 if id == null else id
	func get_peer_actor(id):
		return actor if id in [1, 2, 3] else null
	func check_connection():
		return true
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

class CancerNpcFixture:
	extends Spatial
	var dead = false
	var enabled = true
	var cancer_immunity = false
	var armor = 0
	var objective_removals = 0
	func remove_objective():
		objective_removals += 1

class PropFixture:
	extends "res://MOD_CONTENT/CruS Online/remaped/Kinematic_Physics_Object.gd"
	func _ready():
		glob = Global
		register_all_rpcs()
		set_physics_process(false)

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
	var lobby = Node.new()
	lobby.name = "SteamLobby"
	parent.add_child(lobby)
	var net = Network.new()
	net.name = "SteamNetwork"
	parent.add_child(net)
	net.set_process(false)
	net._my_steam_id = 1
	net._server_steam_id = 1
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
	check(net._valid_packet(net.PACKET_TYPE.HANDSHAKE, var2bytes(2)), "versioned handshake")
	check(not net._valid_packet(net.PACKET_TYPE.HANDSHAKE, null), "legacy handshake rejected")

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
	check(Policy.validate("_do_damage", [25, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 0], true, false), "valid player damage")
	check(not Policy.validate("_do_damage", [-1, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 0], true, false), "negative damage rejected")
	check(not Policy.validate("_set_cancer", [], false, false), "invulnerable target protected")
	check(not Policy.validate("give_money", [], true, false), "arbitrary gameplay method rejected")

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
	prop.free()
	elevator_bridge.actor.free()
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
	mission_exit.presence = [1]
	check(not mission_exit._evaluate_exit() and mission_exit.exitTimer.is_stopped(), "leaving cancels countdown")
	multiplayer.died_players = [2]
	check(mission_exit._evaluate_exit(), "dead player does not prevent surviving player exfil")
	multiplayer.died_players = [1, 2]
	check(not mission_exit._evaluate_exit(), "all dead cannot complete mission")
	multiplayer.died_players = []
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

	var coordinator = Node.new()
	root.add_child(coordinator)
	coordinator.set_script(load("res://MOD_CONTENT/CruS Online/multiplayer.gd"))
	coordinator.NetworkBridge = elevator_bridge
	coordinator.DeathScreen = NotifyFixture.new()
	var restart_timer = Timer.new()
	restart_timer.name = "RestartTimer"
	coordinator.add_child(restart_timer)
	coordinator.players = {1: {}, 2: {}}
	coordinator.hostSettings.canRespawn = true
	coordinator._player_died(1)
	coordinator._player_died(2)
	check(coordinator.died_players.size() == 2 and restart_timer.is_stopped(), "manual respawn tracks deaths without automatic restart")
	coordinator._player_respawn(1)
	coordinator.hostSettings.canRespawn = false
	coordinator._player_died(1)
	check(not restart_timer.is_stopped(), "all dead starts restart when manual respawn disabled")
	coordinator._player_respawn(2)
	check(restart_timer.is_stopped() and not coordinator.died_players.has(2), "revive cancels pending restart and clears dead membership")
	coordinator._player_died(999)
	check(not coordinator.died_players.has(999), "nonmember death ignored")
	coordinator.DeathScreen.free()
	coordinator.free()
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
	print("TRANSPORT_TEST_RESULT failures=", failures)
	get_tree().quit(1 if failures else 0)
