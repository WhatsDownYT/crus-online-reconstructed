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
	var peers = mp.players.keys()
	peers.sort()
	var origin = player.global_transform.origin
	var candidates = [Vector3.ZERO]
	for radius in [1.2, 2.2]:
		for i in range(16):
			candidates.append(Vector3(cos(i * TAU / 16.0), 0, sin(i * TAU / 16.0)) * radius)
	var assigned = []
	var space = get_world().direct_space_state
	var shape = CapsuleShape.new()
	shape.radius = 0.35
	shape.height = 1.0
	var query = PhysicsShapeQueryParameters.new()
	query.set_shape(shape)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
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
