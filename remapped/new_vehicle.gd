extends KinematicBody

onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")
export var turn_amount = 0.3
export var max_speed = 30
var in_use = false
var drive_id = null
var init_player_basis = Basis()
var gravity = 22
var speed = 0.0
var rot_target = 0.0
var velocity = Vector3.ZERO
var velocity_target = Vector3.ZERO
var lerp_transform = Transform()
var camera_rotation
var car_camera
var default_rotation = Vector3.ZERO
var seats = [0, 0, 0, 0]
var seat_positions = []
var local_seat = -1
var seat_entered_frame = -1
var seat_capacity = 1
var sync_elapsed = 0.0
var seat_revision = 0
var last_revision = -1
var occupant_bodies = []

func _ready():
	lerp_transform = global_transform
	seat_capacity = 4 if filename.ends_with("/New_Car.tscn") else 1
	var driver_position = $Car/Player_Pos.translation
	seat_positions = [driver_position, driver_position + Vector3(-0.62, 0, 0), driver_position + Vector3(0, 0, -0.95), driver_position + Vector3(-0.62, 0, -0.95)]
	car_camera = $Car/Camera
	default_rotation = car_camera.rotation
	camera_rotation = Spatial.new()
	$Car.add_child(camera_rotation)
	camera_rotation.translation = car_camera.translation
	$Car.remove_child(car_camera)
	camera_rotation.add_child(car_camera)
	car_camera.translation = Vector3.ZERO
	NetworkBridge.register_rpcs(self, [["sync_vehicle_pose", NetworkBridge.PERMISSION.SERVER], ["request_vehicle_pose", NetworkBridge.PERMISSION.ALL], ["request_seat", NetworkBridge.PERMISSION.ALL], ["request_exit", NetworkBridge.PERMISSION.ALL], ["sync_seats", NetworkBridge.PERMISSION.SERVER]])
	set_collision_layer_bit(8, true)
	Global.get_node("Multiplayer").connect("scene_loaded", self, "_publish_seats")

func align_up(node_basis, normal):
	var result = Basis()
	var object_scale = node_basis.get_scale()
	result.x = normal.cross(node_basis.z) + Vector3(0.00001, 0, 0)
	result.y = normal + Vector3(0, 0.00001, 0)
	result.z = node_basis.x.cross(normal) + Vector3(0, 0, 0.00001)
	result = result.orthonormalized()
	result.x *= object_scale.x
	result.y *= object_scale.y
	result.z *= object_scale.z
	return result

func _physics_process(delta):
	var local_driver = drive_id == NetworkBridge.get_id()
	var simulate = local_driver or drive_id == null and NetworkBridge.is_world_authority()
	if simulate:
		var normal = Vector3.ZERO
		var count = 0
		for ray in $RayCasts.get_children():
			if ray.is_colliding():
				normal += ray.get_collision_normal()
				count += 1
		if count > 0:
			var yaw = rotation.y
			transform.basis = transform.basis.orthonormalized().slerp(align_up(transform.basis, normal / count), min(1.0, delta * 1.5))
			rotation.y = yaw
		var controls = local_driver and is_instance_valid(Global.player) and not Global.player.dead and Global.player._gameplay_input_enabled()
		if controls and count > 0:
			if Input.is_action_pressed("movement_jump"): speed = lerp(speed, 0, min(1.0, delta * 5))
			speed += (Input.get_action_strength("movement_forward") - Input.get_action_strength("movement_backward")) * delta * 30.0
			speed = clamp(speed, -max_speed / 2.0, max_speed)
			rot_target += (Input.get_action_strength("movement_left") - Input.get_action_strength("movement_right")) * speed * delta * 0.1
		rot_target = lerp(rot_target, 0, min(1.0, delta * 2))
		rotate_object_local(Vector3.UP, rot_target * delta * 3)
		speed = lerp(speed, 0, min(1.0, delta))
		var vertical = velocity.y
		velocity_target = global_transform.basis.z.normalized() * speed
		velocity = velocity.linear_interpolate(velocity_target, min(1.0, delta * 3))
		velocity.y = vertical - gravity * delta
		velocity = move_and_slide(velocity, Vector3.UP, false, 4)
		sync_elapsed += delta
		if sync_elapsed >= 0.05:
			sync_elapsed = 0.0
			if NetworkBridge.is_world_authority():
				NetworkBridge.n_rpc_unreliable(self, "sync_vehicle_pose", [global_transform, speed])
			else:
				NetworkBridge.n_rpc_unreliable_id(self, NetworkBridge.get_host_id(), "request_vehicle_pose", [global_transform, speed])
	else:
		global_transform = global_transform.interpolate_with(lerp_transform, min(1.0, delta * 12))
	if drive_id != null and abs(speed) > 0.1:
		$SFX_Engine.pitch_scale = max(0.1, (abs(speed) + 0.01) * 0.1)
		if not $SFX_Engine.playing: $SFX_Engine.play()
	else:
		$SFX_Engine.stop()
	if local_seat >= 0 and is_instance_valid(Global.player):
		if Global.player.dead:
			eject()
		else:
			Global.player.global_transform.origin = $Car.global_transform.xform(seat_positions[local_seat])
			Global.player.global_rotation.y = global_rotation.y
	if NetworkBridge.is_world_authority() and NetworkBridge.check_connection():
		var changed = false
		for index in range(seat_capacity):
			if seats[index] != 0 and not Global.get_node("Multiplayer").players.has(seats[index]):
				seats[index] = 0
				changed = true
		if changed: _publish_seats()

master func request_vehicle_pose(id, pose, new_speed = 0.0):
	if not NetworkBridge.is_world_authority() or NetworkBridge.request_sender(id) != drive_id or typeof(pose) != TYPE_TRANSFORM: return
	lerp_transform = pose
	speed = clamp(float(new_speed), -max_speed, max_speed)
	NetworkBridge.n_rpc_unreliable(self, "sync_vehicle_pose", [pose, speed])

puppet func sync_vehicle_pose(_id, pose, new_speed = 0.0):
	lerp_transform = pose
	speed = new_speed

func player_use():
	if not is_instance_valid(Global.player) or Global.player.dead or Global.player.car != null: return
	NetworkBridge.request_host(self, "request_seat", [])

master func request_seat(id):
	if not NetworkBridge.is_world_authority(): return
	var peer = NetworkBridge.request_sender(id)
	var actor = NetworkBridge.get_peer_actor(peer)
	if actor == null or actor.global_transform.origin.distance_to(global_transform.origin) > 8.0 or seats.has(peer): return
	var index = seats.find(0)
	if index < 0 or index >= seat_capacity: return
	seats[index] = peer
	_publish_seats()

func eject():
	if local_seat < 0: return
	NetworkBridge.request_host(self, "request_exit", [])
	_leave_local_seat()

master func request_exit(id):
	if not NetworkBridge.is_world_authority(): return
	var index = seats.find(NetworkBridge.request_sender(id))
	if index < 0: return
	seats[index] = 0
	_publish_seats()

func _publish_seats():
	if not NetworkBridge.is_world_authority(): return
	seat_revision += 1
	sync_seats(null, seats.duplicate(), seat_revision)
	NetworkBridge.n_rpc(self, "sync_seats", [seats.duplicate(), seat_revision])

puppet func sync_seats(_id, occupants, revision):
	if not occupants is Array or occupants.size() != 4 or revision < last_revision: return
	last_revision = revision
	seats = occupants.duplicate()
	drive_id = seats[0] if seats[0] != 0 else null
	in_use = drive_id != null
	var assigned = seats.find(NetworkBridge.get_id())
	if assigned != local_seat:
		if local_seat >= 0: _leave_local_seat()
		if assigned >= 0: _enter_local_seat(assigned)
	_sync_occupant_collisions()

func _sync_occupant_collisions():
	for body in occupant_bodies:
		if not is_instance_valid(body): continue
		remove_collision_exception_with(body)
		body.remove_collision_exception_with(self)
		for ray in $RayCasts.get_children(): ray.remove_exception(body)
	occupant_bodies.clear()
	var mp = Global.get_node("Multiplayer")
	for peer in seats:
		if peer == 0: continue
		var actor = Global.player if peer == NetworkBridge.get_id() else mp.Players.get_node_or_null(str(peer))
		if not is_instance_valid(actor): continue
		var pending = [actor]
		while not pending.empty():
			var node = pending.pop_back()
			pending.append_array(node.get_children())
			if not node is PhysicsBody or node == self: continue
			occupant_bodies.append(node)
			add_collision_exception_with(node)
			node.add_collision_exception_with(self)
			for ray in $RayCasts.get_children(): ray.add_exception(node)

func _enter_local_seat(index):
	if not is_instance_valid(Global.player): return
	local_seat = index
	seat_entered_frame = Engine.get_idle_frames()
	init_player_basis = Global.player.transform.basis
	camera_rotation.translation = $Car.to_local($Car/Player_Pos.global_transform.origin) + Vector3(0, 1.56, 0) + (seat_positions[index] - seat_positions[0])
	camera_rotation.rotation = Vector3.ZERO
	car_camera.rotation = default_rotation
	car_camera.current = true
	Global.player.car = self
	Global.player.get_parent().hide()
	Global.player.weapon.disabled = true
	Global.player.grab_hand.hide()
	Global.player.crush_check.set_deferred("disabled", true)
	Global.player.disabled = true
	Global.player.set_collision_mask_bit(7, false)
	if is_instance_valid(Global.player.playerPuppet): Global.player.playerPuppet.set_sit(null, true)

func _leave_local_seat():
	if local_seat < 0: return
	if not is_instance_valid(Global.player):
		local_seat = -1
		return
	var index = local_seat
	local_seat = -1
	car_camera.current = false
	Global.player.car = null
	Global.player.transform.basis = init_player_basis
	Global.player.global_transform.origin = $ExitPos.global_transform.origin + global_transform.basis.x * (-3.0 if index in [1, 3] else 0.0)
	Global.player.player_velocity = Vector3.ZERO
	Global.player.set_collision_mask_bit(7, true)
	Global.player.crush_check.set_deferred("disabled", false)
	Global.player.get_parent().show()
	Global.player.show()
	Global.player.grab_hand.show()
	Global.player.player_view.current = true
	Global.player.weapon.disabled = false
	Global.player.disabled = false
	if is_instance_valid(Global.player.playerPuppet): Global.player.playerPuppet.set_sit(null, false)

func _process(_delta):
	if local_seat >= 0 and Engine.get_idle_frames() > seat_entered_frame and Global.player._gameplay_input_enabled() and Input.is_action_just_pressed("Use"):
		eject()

func _input(event):
	if local_seat >= 0 and event is InputEventMouseMotion and Global.player._gameplay_input_enabled() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.rotation.y -= deg2rad(event.relative.x * Global.mouse_sensitivity)
		camera_rotation.rotation.x = clamp(camera_rotation.rotation.x + deg2rad(event.relative.y * Global.mouse_sensitivity) * (-1.0 if Global.invert_y else 1.0), -1.2, 1.2)

func _on_VehicleBody_body_entered(_body):
	pass

func _on_Vehicle_body_entered(body):
	if body.has_method("physics_object") and NetworkBridge.is_world_authority(): body.queue_free()

func _on_Area_body_entered(body):
	if not NetworkBridge.is_world_authority() or abs(speed) < 15: return
	var target = NetworkBridge.damage_target_id(body)
	if target > 0 and seats.has(target): return
	if body.has_method("damage"):
		NetworkBridge.apply_damage(self, body, "damage", [200, (global_transform.origin - body.global_transform.origin).normalized(), body.global_transform.origin, global_transform.origin])
