extends Spatial

onready var player = $Player
onready var cam_pos = $Position3D

func _ready():
	if Global.implants.head_implant.shrink:
		scale = Vector3(0.1, 0.1, 0.1)
	
	if not Global.get_node("Multiplayer/NetworkBridge").check_connection():
		return

	var respawnPoint = preload("res://MOD_CONTENT/CruS Online/maps_stuff/respawn_point.tscn").instance()
	get_node("..").call_deferred("add_child", respawnPoint)
	respawnPoint.transform = transform
	
	call_deferred("_spread_spawn")

func _spread_spawn():
	var mp = Global.get_node("Multiplayer")
	if not mp.NetworkBridge.check_connection():
		return
	if mp.Deathmatch.is_active():
		return
	var peers = mp.players.keys()
	peers.sort()
	if mp.CounterOp.is_active():
		var operative_peers = []
		for peer in peers:
			if mp.CounterOp.is_operative(peer):
				operative_peers.append(peer)
		peers = operative_peers
	var origin = player.global_transform.origin
	var assigned = []
	var space = get_world().direct_space_state
	var shape = CapsuleShape.new()
	shape.radius = 0.35
	shape.height = 1.0
	var query = PhysicsShapeQueryParameters.new()
	query.set_shape(shape)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	if mp.CounterOp.is_active() and mp.CounterOp.is_counter_operative(mp.NetworkBridge.get_id()):
		var counter_spawn = _counterop_spawn(mp, space, query)
		if counter_spawn != null:
			player.global_transform.origin = counter_spawn
			cam_pos.global_transform.origin = counter_spawn + Vector3.UP * 1.481
			return
	var candidates = [Vector3.ZERO]
	for radius in [1.2, 2.2]:
		for i in range(16):
			candidates.append(Vector3(cos(i * TAU / 16.0), 0, sin(i * TAU / 16.0)) * radius)
	for peer in peers:
		var spawn = origin
		for offset in candidates:
			var floor_hit = space.intersect_ray(origin + offset + Vector3.UP * 2, origin + offset + Vector3.DOWN * 3, [player], 1)
			if floor_hit.empty() or floor_hit.normal.y < 0.65:
				continue
			var point = floor_hit.position + Vector3.UP * 0.1
			if abs(point.y - origin.y) > 1.0:
				continue
			var overlaps = false
			for used in assigned:
				if used.distance_to(point) < 0.85:
					overlaps = true
			if overlaps:
				continue
			query.transform = Transform(Basis(), point + Vector3.UP * 0.85)
			if not space.intersect_shape(query, 1).empty():
				continue
			spawn = point
			break
		assigned.append(spawn)
		if peer == mp.NetworkBridge.get_id():
			player.global_transform.origin = spawn
			cam_pos.global_transform.origin = spawn + Vector3.UP * 1.481
			return

func _counterop_spawn(mp, space, query):
	var spots = []
	var scene = get_tree().current_scene
	if not is_instance_valid(scene):
		return null
	_collect_civilian_spots(scene, spots)
	if spots.empty():
		return null
	var rng = RandomNumberGenerator.new()
	rng.seed = int(mp.SteamNetwork.scene_epoch) * 1103515245 + int(Global.CURRENT_LEVEL) * 12345 + spots.size() * 97
	for i in range(spots.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var swap = spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	var counter_peers = []
	for peer in mp.players:
		if mp.CounterOp.is_counter_operative(peer):
			counter_peers.append(peer)
	counter_peers.sort()
	var local_index = counter_peers.find(mp.NetworkBridge.get_id())
	if local_index < 0:
		return null
	for attempt in range(spots.size()):
		var spot = spots[(local_index + attempt) % spots.size()]
		var spawn = _safe_civilian_spawn(spot, space, query)
		if spawn != null:
			return spawn
	return null

func _collect_civilian_spots(node, result):
	if node != self and "civilian" in node and bool(node.get("civilian")) and (not ("objective" in node) or not bool(node.get("objective"))):
		var position = node.global_transform.origin
		if position.distance_to(Vector3(1000, 1000, 1000)) > 10.0:
			result.append(position)
	for child in node.get_children():
		_collect_civilian_spots(child, result)

func _safe_civilian_spawn(origin, space, query):
	var offsets = []
	for radius in [0.9, 1.3, 1.8]:
		for i in range(12):
			offsets.append(Vector3(cos(i * TAU / 12.0), 0, sin(i * TAU / 12.0)) * radius)
	for offset in offsets:
		var floor_hit = space.intersect_ray(origin + offset + Vector3.UP * 2.5, origin + offset + Vector3.DOWN * 4, [player], 1)
		if floor_hit.empty() or floor_hit.normal.y < 0.65:
			continue
		var point = floor_hit.position + Vector3.UP * 0.1
		if abs(point.y - origin.y) > 2.5:
			continue
		query.transform = Transform(Basis(), point + Vector3.UP * 0.85)
		if space.intersect_shape(query, 1).empty():
			return point
	return null

func _process(delta):
	if Input.is_action_just_pressed("Stocks") and not Global.get_node("Multiplayer/Menu").visible:
		$Stock_Menu.visible = not $Stock_Menu.visible
		if $Stock_Menu.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			$Position3D / Rotation_Helper / Weapon.disabled = true
		else :
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			$Position3D / Rotation_Helper / Weapon.disabled = false
	var offset = Vector3(0, 1.481, 0)
	if Global.implants.head_implant.shrink:
		offset *= 0.1
	if player.max_gravity < 0:
		offset = Vector3(0, 0, 0)
	if Engine.get_frames_per_second() <= 30:
		cam_pos.global_transform.origin = player.global_transform.origin + offset
	else :
		cam_pos.global_transform.origin = lerp(cam_pos.global_transform.origin, player.global_transform.origin + offset, clamp(delta * 30, 0, 1))
		
	cam_pos.rotation.y = player.rotation.y
