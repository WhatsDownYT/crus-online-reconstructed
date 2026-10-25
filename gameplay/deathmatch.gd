extends Node

onready var Multiplayer = get_parent()
onready var NetworkBridge = get_parent().get_node("NetworkBridge")
var civilian_spots = []
var fallback_spots = []
var spawn_points = []
var participants = []
var relocation_times = {}
var started = false

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	NetworkBridge.register_rpcs(self, [["relocate", NetworkBridge.PERMISSION.SERVER]])

func is_active():
	return NetworkBridge.check_connection() and Multiplayer.hostSettings.get("gameMode", "cruelty") == "deathmatch"

func spawn_npcs():
	return bool(Multiplayer.hostSettings.get("deathmatchSpawnNPCs", true))

func reset_round():
	civilian_spots.clear()
	fallback_spots.clear()
	spawn_points.clear()
	participants.clear()
	relocation_times.clear()
	started = false

func suppress_npc(node):
	node.set_meta("deathmatch_removed", true)
	for child in node.get_children():
		suppress_npc(child)

func register_npc(npc):
	var point = npc.global_transform.origin
	if point.distance_to(Vector3(1000, 1000, 1000)) < 10.0:
		return
	fallback_spots.append(point)
	if npc.civilian and not npc.objective:
		civilian_spots.append(point)

func start_round():
	if not is_active() or not NetworkBridge.is_world_authority():
		return
	participants = Multiplayer.players.keys()
	participants.sort()
	var manager = Global.player.get_parent()
	var space = Global.player.get_world().direct_space_state
	var shape = CapsuleShape.new()
	shape.radius = 0.35
	shape.height = 1.0
	var query = PhysicsShapeQueryParameters.new()
	query.set_shape(shape)
	query.collision_mask = 1
	query.exclude = [Global.player.get_rid()]
	for spot in civilian_spots:
		var safe = manager._safe_civilian_spawn(spot, space, query)
		if safe != null and not spawn_points.has(safe):
			spawn_points.append(safe)
	if spawn_points.size() < participants.size():
		for spot in fallback_spots:
			var safe = manager._safe_civilian_spawn(spot, space, query)
			if safe != null and not spawn_points.has(safe):
				spawn_points.append(safe)
	if spawn_points.empty():
		spawn_points.append(Global.player.global_transform.origin)
	if spawn_points.size() < participants.size():
		var bases = spawn_points.duplicate()
		for origin in bases:
			for radius in [2.0, 4.0, 6.0]:
				for angle in range(8):
					var offset = Vector3(cos(angle * TAU / 8.0), 0, sin(angle * TAU / 8.0)) * radius
					var safe = manager._safe_civilian_spawn(origin + offset, space, query)
					if safe != null and not spawn_points.has(safe):
						spawn_points.append(safe)
	spawn_points.shuffle()
	var used = []
	for peer in participants:
		var point = choose_spawn(used)
		used.append(point)
		_send_relocation(peer, point)
	Global.objectives = 0
	Global.objectives_total = 0
	Global.objective_complete = false
	started = true

func spread_counter_operative_spawns():
	if not Multiplayer.CounterOp.is_active() or not NetworkBridge.is_world_authority():
		return
	var peers = []
	for peer in Multiplayer.players:
		if Multiplayer.CounterOp.is_counter_operative(peer):
			peers.append(peer)
	peers.sort()
	if peers.empty():
		return
	var manager = Global.player.get_parent()
	var space = Global.player.get_world().direct_space_state
	var shape = CapsuleShape.new()
	shape.radius = 0.35
	shape.height = 1.0
	var query = PhysicsShapeQueryParameters.new()
	query.set_shape(shape)
	query.collision_mask = 1
	query.exclude = [Global.player.get_rid()]
	spawn_points.clear()
	for spot in civilian_spots:
		var safe = manager._safe_civilian_spawn(spot, space, query)
		if safe != null and not spawn_points.has(safe):
			spawn_points.append(safe)
	if spawn_points.size() < peers.size():
		for spot in fallback_spots:
			var safe = manager._safe_civilian_spawn(spot, space, query)
			if safe != null and not spawn_points.has(safe):
				spawn_points.append(safe)
	if spawn_points.empty():
		return
	spawn_points.shuffle()
	var used = []
	for peer in peers:
		var point = choose_spawn(used)
		used.append(point)
		_send_relocation(peer, point)

func choose_spawn(occupied):
	var best = spawn_points[randi() % spawn_points.size()]
	var best_distance = -1.0
	for point in spawn_points:
		var distance = INF
		for other in occupied:
			distance = min(distance, point.distance_squared_to(other))
		if distance > best_distance:
			best_distance = distance
			best = point
	return best

func relocate_from_exit(peer):
	if not is_active() or not started or not NetworkBridge.is_world_authority() or Multiplayer.Flow.result_active or Multiplayer.died_players.has(peer) or Multiplayer.Flow.waiting_peers.has(peer):
		return
	if OS.get_ticks_msec() - int(relocation_times.get(peer, -5000)) < 1500:
		return
	var occupied = []
	for other in Multiplayer.players:
		var actor = NetworkBridge.get_peer_actor(other)
		if is_instance_valid(actor) and not Multiplayer.died_players.has(other):
			occupied.append(actor.global_transform.origin)
	var point = choose_spawn(occupied)
	relocation_times[peer] = OS.get_ticks_msec()
	_send_relocation(peer, point)

func _send_relocation(peer, point):
	NetworkBridge.n_rpc(self, "relocate", [peer, point, Multiplayer.SteamNetwork.scene_epoch])
	relocate(null, peer, point, Multiplayer.SteamNetwork.scene_epoch)

puppet func relocate(id, peer, point, epoch):
	if not (is_active() or Multiplayer.CounterOp.is_active()) or epoch != Multiplayer.SteamNetwork.scene_epoch or typeof(point) != TYPE_VECTOR3:
		return
	var actor = NetworkBridge.get_peer_actor(peer)
	if not is_instance_valid(actor):
		return
	actor.global_transform.origin = point
	if "transform_lerp" in actor:
		actor.transform_lerp.origin = point
	if peer == NetworkBridge.get_id():
		Global.player.get_parent().cam_pos.global_transform.origin = point + Vector3.UP * 1.481
		if "velocity" in actor:
			actor.velocity = Vector3.ZERO

func check_round():
	if not is_active() or not started or not NetworkBridge.is_world_authority() or Multiplayer.Flow.result_active or Multiplayer.Flow.finishing:
		return
	var alive = []
	for peer in participants:
		if Multiplayer.players.has(peer) and not Multiplayer.died_players.has(peer) and not Multiplayer.Flow.waiting_peers.has(peer):
			alive.append(peer)
	if alive.size() <= 1 and participants.size() > 1:
		Multiplayer.Flow.finish_mission(not alive.empty(), "deathmatch", alive[0] if not alive.empty() else 0)

func _process(_delta):
	if is_active() and started and Global.menu.in_game:
		check_round()
