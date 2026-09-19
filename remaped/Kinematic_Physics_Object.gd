extends KinematicBody

const InteractionPolicy = preload("res://MOD_CONTENT/CruS Online/PropInteractionPolicy.gd")



onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

var velocity = Vector3(0, 0, 0)
var gravity = 22
var held = false
var alerter = false
export  var grillable = false
var grill = false
var grill_health = 50
var grill_flag = false
var damager = false
export  var disabled = false
export  var usable = true
var alert_sphere = preload("res://Entities/Alert_Sphere_Big.tscn")
var blood_decal = preload("res://Entities/Decals/FleshDecal1.tscn")
export  var type = 1
export  var player_head = false
export  var particle = true
export  var mass = 1
export  var gun_rotation = false
export  var flesh = false
var angular_velocity = 0
export  var gas = false
var gas_cloud = preload("res://Entities/Bullets/Poison_Gas.tscn")
export  var collidable = false
export  var rotate_b = true
export  var shell = false
var grill_healing_item = preload("res://Entities/healing_item.tscn")
export  var stay_active = false
var impact_sound:Array
export  var sounds = false
var rot_changed = Vector3(0, 0, 0)
var t = 0
var water = false
var finished = false
var no_rot = false
var gun
var rot_towards
var rot_towards_z = 0
var rot_towards_x = 0
var rot_towards_y = 0
var new_alert_sphere
var particle_node
var sphere_collision
var distance
var glob
var first_col = true

var change_transform = true

onready var Multiplayer = Global.get_node("Multiplayer")



var holdId = 0
var holder_throw_bonus = 0.0
var physics_revision = 0
var _hold_collision_saved = false
var _hold_layer = 0
var _hold_mask = 0
var _hold_shape_disabled = false

var playerIgnoreId = 0

puppet func _sync_vars(id, recDisabled,recUsable,recGrill_health,recSphere_collision,recDamager,recHeld):
	disabled = recDisabled
	usable = recUsable
	grill_health = recGrill_health
	sphere_collision.disabled = recSphere_collision
	damager = recDamager
	held = recHeld

remote func _set_grill(id, value):
	grill = value

remote func _spawn_fake_gas(id, pos):
	var fake_gas_cloud = preload("res://MOD_CONTENT/CruS Online/effects/fake_poison_gas.tscn").instance()
	get_parent().add_child(fake_gas_cloud)
	fake_gas_cloud.global_transform.origin = pos

remote func _grill(id, recivedPos):
	grill_flag = true
	$Gib.get_child(0).material_override = load("res://Materials/grilled.tres")
	var new_healing = grill_healing_item.instance()
	add_child(new_healing)
	new_healing.global_transform.origin = recivedPos

remote func _create_blood_decal(id, collider, recivedTransform, recivedBasis):
	var surface = get_node_or_null(collider)
	if surface == null:
		return
	var decals = get_tree().get_nodes_in_group("crus_blood_decals")
	while decals.size() >= 256:
		var oldest = decals.pop_front()
		oldest.remove_from_group("crus_blood_decals")
		oldest.queue_free()
	var new_blood_decal = blood_decal.instance()
	surface.add_child(new_blood_decal)
	new_blood_decal.add_to_group("crus_blood_decals")
	new_blood_decal.global_transform.origin = recivedTransform
	new_blood_decal.transform.basis = recivedBasis

puppet func _remove(id):
	hide()
	global_translation = Vector3(-1000, -1000, -1000)
	
	gas = false
	
	set_process(false)
	set_physics_process(false)

func syncUpdate():
	if gun != null:
		gun.syncUpdate()

var lerp_transform : Transform
var last_transform : Transform

puppet func client_set_lerp_transform(id, recived_transform, revision = 0):
	if revision != physics_revision:
		return
	lerp_transform = recived_transform
	set_physics_process(true)

master func set_lerp_transform(id, recived_transform, revision = 0):
	if revision != physics_revision:
		return
	id = NetworkBridge.request_sender(id)
	if not NetworkBridge.is_world_authority() or not held or id != holdId:
		return
	var actor = NetworkBridge.get_peer_actor(id)
	if actor == null or typeof(recived_transform) != TYPE_TRANSFORM or not InteractionPolicy.finite_vector(recived_transform.origin) or recived_transform.origin.distance_to(actor.global_transform.origin) > 6.0:
		return
	global_transform = recived_transform
	lerp_transform = recived_transform
	velocity = Vector3.ZERO
	NetworkBridge.n_rpc_unreliable(self, "client_set_lerp_transform", [recived_transform, physics_revision])

func move_held(recived_transform):
	if not held or holdId != NetworkBridge.get_id():
		return
	global_transform = recived_transform
	velocity = Vector3.ZERO
	if NetworkBridge.is_world_authority():
		NetworkBridge.n_rpc_unreliable(self, "client_set_lerp_transform", [recived_transform, physics_revision])
	else:
		NetworkBridge.n_rpc_unreliable(self, "set_lerp_transform", [recived_transform, physics_revision])

var tick = 0

func host_tick():
	tick += 1
	if ((global_transform.origin - last_transform.origin).length() > 0.01 or not global_transform.basis.is_equal_approx(last_transform.basis)) and tick % 2 == 0:
		last_transform = global_transform
		
		if NetworkBridge.n_is_network_master(self):
			NetworkBridge.n_rpc_unreliable(self, "client_set_lerp_transform", [global_transform, physics_revision])
		else:
			NetworkBridge.n_rpc_unreliable(self, "set_lerp_transform", [global_transform, physics_revision])
		
		tick = 0

func register_all_rpcs():
	NetworkBridge.register_rpcs(self, [
		["_get_transform", NetworkBridge.PERMISSION.ALL],
		["set_network_transform", NetworkBridge.PERMISSION.ALL],
		["network_add_velocity", NetworkBridge.PERMISSION.ALL],
		["request_radio_throw", NetworkBridge.PERMISSION.ALL],
		["_sync_vars", NetworkBridge.PERMISSION.SERVER],
		["_set_grill", NetworkBridge.PERMISSION.ALL],
		["_spawn_fake_gas", NetworkBridge.PERMISSION.ALL],
		["_grill", NetworkBridge.PERMISSION.ALL],
		["_create_blood_decal", NetworkBridge.PERMISSION.ALL],
		["_remove", NetworkBridge.PERMISSION.SERVER],
		["_set_hold_collision", NetworkBridge.PERMISSION.SERVER],
		["set_lerp_transform", NetworkBridge.PERMISSION.ALL],
		["client_set_lerp_transform", NetworkBridge.PERMISSION.SERVER],
		["set_hold_object", NetworkBridge.PERMISSION.ALL],
		["set_drop_object", NetworkBridge.PERMISSION.ALL],
		["request_hold", NetworkBridge.PERMISSION.ALL],
		["request_release", NetworkBridge.PERMISSION.ALL],
		["sync_hold_state", NetworkBridge.PERMISSION.SERVER],
		["sync_settled_pose", NetworkBridge.PERMISSION.SERVER],
		["network_set_grill", NetworkBridge.PERMISSION.ALL],
		["network_damage", NetworkBridge.PERMISSION.ALL]
	])
	
	NetworkBridge.register_rset(self, "global_transform", NetworkBridge.PERMISSION.SERVER)
	NetworkBridge.register_rset(self, "lerp_transform", NetworkBridge.PERMISSION.SERVER)
	
	NetworkBridge.register_rset(self, "holdId", NetworkBridge.PERMISSION.SERVER)
	NetworkBridge.register_rset(self, "disabled", NetworkBridge.PERMISSION.SERVER)
	NetworkBridge.register_rset(self, "usable", NetworkBridge.PERMISSION.SERVER)
	NetworkBridge.register_rset(self, "grill_health", NetworkBridge.PERMISSION.SERVER)
	NetworkBridge.register_rset(self, "stay_active", NetworkBridge.PERMISSION.SERVER)
	NetworkBridge.register_rset(self, "finished", NetworkBridge.PERMISSION.SERVER)

	rset_config("global_transform", MultiplayerAPI.RPC_MODE_PUPPET)
	rset_config("lerp_transform", MultiplayerAPI.RPC_MODE_PUPPET)

	rset_config("holdId", MultiplayerAPI.RPC_MODE_PUPPET)
	rset_config("disabled", MultiplayerAPI.RPC_MODE_PUPPET)
	rset_config("usable", MultiplayerAPI.RPC_MODE_PUPPET)
	rset_config("grill_health", MultiplayerAPI.RPC_MODE_PUPPET)
	rset_config("stay_active",MultiplayerAPI.RPC_MODE_PUPPET)
	rset_config("finished",MultiplayerAPI.RPC_MODE_PUPPET)



func _ready()->void :
	lerp_transform = global_transform
	


	
	register_all_rpcs()

	glob = Global
	if particle:
		particle_node = get_node_or_null("Particle")
	new_alert_sphere = alert_sphere.instance()
	add_child(new_alert_sphere)
	new_alert_sphere.global_transform.origin = global_transform.origin
	sphere_collision = new_alert_sphere.get_node("CollisionShape")
	sphere_collision.disabled = true
	gun = get_node_or_null("Area")
	set_collision_layer_bit(6, 1)
	set_collision_layer_bit(2, 0)
	set_collision_mask_bit(2, 1)
	set_collision_mask_bit(3, 1)
	rot_towards = global_transform.origin - velocity
	if not collidable:
		set_collision_layer_bit(0, 0)
	t += rand_range(0, 10)
	t = round(t)
	if sounds:
		impact_sound = [$Sound1]
		for sound in impact_sound:
			sound.pitch_scale = max(0.1, sound.pitch_scale - mass * 0.1)
	if gun_rotation:
		yield (get_tree(), "idle_frame")
		angular_velocity = Vector2(velocity.x, velocity.z).length()
	
	if NetworkBridge.check_connection() and not NetworkBridge.n_is_network_master(self):
		axis_lock_motion_x = true
		axis_lock_motion_y = true
		axis_lock_motion_z = true
		
		NetworkBridge.n_rpc(self, "_get_transform")

master func _get_transform(id):
	if NetworkBridge.is_world_authority():
		NetworkBridge.n_rpc_id(self, NetworkBridge.request_sender(id), "sync_hold_state", [holdId, global_transform, velocity, damager, alerter, physics_revision])

master func set_network_transform(id, recivedTransform, only_origin = false):

	set_lerp_transform(id, recivedTransform, physics_revision)

func add_velocity(recivedVelocity):
	network_add_velocity(null, recivedVelocity)

master func request_radio_throw(id, position, throw_velocity):
	if not NetworkBridge.is_world_authority():
		return
	id = NetworkBridge.request_sender(id)
	var actor = NetworkBridge.get_peer_actor(id)
	if filename != "res://Entities/Physics_Objects/radio.tscn" or not has_meta("crus_radio_owner") or int(get_meta("crus_radio_owner")) != id or actor == null:
		return
	if not InteractionPolicy.finite_vector(position) or not InteractionPolicy.finite_vector(throw_velocity) or position.distance_to(actor.global_transform.origin) > 6.0 or throw_velocity.length() > 200:
		return
	physics_revision += 1
	var pose = global_transform
	pose.origin = position
	sync_hold_state(null, 0, pose, throw_velocity, false, false, physics_revision)
	NetworkBridge.n_rpc(self, "sync_hold_state", [0, pose, throw_velocity, false, false, physics_revision])

master func network_add_velocity(id, recivedVelocity):
	if NetworkBridge.n_is_network_master(self):
		finished = false
		t = 0
		set_physics_process(true)
		velocity += recivedVelocity
	else:
		NetworkBridge.n_rpc(self, "network_add_velocity", [recivedVelocity])

func set_hold_collision(recived_holding):
	_set_hold_collision(null, recived_holding)

puppet func _set_hold_collision(id, recived_holding):
	if recived_holding:
		if not _hold_collision_saved:
			_hold_layer = collision_layer
			_hold_mask = collision_mask
			_hold_shape_disabled = $CollisionShape.disabled
			_hold_collision_saved = true
		$CollisionShape.disabled = true
		set_collision_layer_bit(6, 0)
		set_collision_mask_bit(0, 0)
	else:
		if _hold_collision_saved:
			collision_layer = _hold_layer
			collision_mask = _hold_mask
			$CollisionShape.disabled = _hold_shape_disabled
			_hold_collision_saved = false

func _physics_process(delta):
	if held:
		if NetworkBridge.is_world_authority() and NetworkBridge.get_peer_actor(holdId) == null:
			_commit_release(false, Vector3.ZERO)
		elif holdId != NetworkBridge.get_id():
			global_transform = global_transform.interpolate_with(lerp_transform, clamp(delta * 10.0, 0, 1))
		return
	if disabled:
		$CollisionShape.disabled = true
		set_physics_process(false)
		return

	t += 1

	if holdId == NetworkBridge.get_id() or not held and NetworkBridge.n_is_network_master(self):
		host_tick()

	if NetworkBridge.n_is_network_master(self):
		
		if fmod(t, 300) == 0 and (velocity.x < 0.01 and velocity.y < 0.01):
			change_transform = false
		if velocity.x > 0.05 or velocity.y > 0.05:
			change_transform = true
		




		if not stay_active and not gun_rotation or global_transform.origin.distance_to(glob.player.global_transform.origin) > 30:
			if fmod(t, 2) == 0:
				return
			else :
				delta *= 2
		if grillable and grill:
			usable = false
			grill_health -= 1

		if grill_health <= 0 and not grill_flag:
			grill_flag = true
			$Gib.get_child(0).material_override = load("res://Materials/grilled.tres")
			var new_healing = grill_healing_item.instance()
			add_child(new_healing)
			new_healing.global_transform.origin = global_transform.origin
			NetworkBridge.n_rpc(self, "_grill", [new_healing.global_transform.origin])













		if player_head:
			rot_towards = lerp(rot_towards, global_transform.origin - velocity, 5 * delta)
			if rot_towards.length() > 0.5:
				look_at(Vector3(rot_towards.x + 1e-06, global_transform.origin.y, rot_towards.z), Vector3.UP)

		if water:
			gravity = 2
		else :
			gravity = 22

		if finished:
			return

		if gun_rotation:
			rotation.y += angular_velocity

		if not player_head and rotate_b:
			rotation.z = lerp(rotation.z, rot_towards_z, 0.5)
			rotation.x = lerp(rotation.x, rot_towards_x, 0.5)
		if Vector3(velocity.x, 0, velocity.z).length() > 0.4 and rotate_b:
			rot_towards_x -= velocity.length()
		elif not player_head and not no_rot and not gun_rotation and not gas:
			rotation = rot_changed

		var collision = move_and_collide(velocity * delta)

		if collision and alerter and velocity.length() > 7:
			sphere_collision.disabled = false
		elif sphere_collision.disabled == false:
			sphere_collision.disabled = true
			
		if collision and (t < 200 or stay_active):
			if velocity.length() > 5 and flesh and Global.fps > 30:
				var decal_basis = align_up(Basis(), collision.normal)
				_create_blood_decal(null, collision.collider.get_path(), collision.position, decal_basis)
				NetworkBridge.n_rpc(self, "_create_blood_decal", [collision.collider.get_path(), collision.position, decal_basis])
			if Vector2(velocity.x, velocity.z).length() > 5 and (gun_rotation or holder_throw_bonus > 0):
				if collision.collider.has_method("damage"):
					var is_thrower = "client" in collision.collider and str(collision.collider.client.name) == str(playerIgnoreId)
					if not is_thrower:
						damager = false
						NetworkBridge.apply_damage(self, collision.collider, "damage", [100, collision.normal, collision.position, global_transform.origin])
			elif sounds and abs(velocity.length()) > 2 and Global.fps > 30:
				var current_sound = 0
				impact_sound[current_sound].pitch_scale = clamp(impact_sound[current_sound].pitch_scale + rand_range( - 0.1, 0.1), 0.8, 1.2)
				impact_sound[current_sound].pitch_scale = clamp(impact_sound[current_sound].pitch_scale, 0.8, 1.2)
				impact_sound[current_sound].unit_db = velocity.length() * 0.1 - 1
				impact_sound[current_sound].play()
			if gas and velocity.length() > 4:
				var new_gas_cloud = gas_cloud.instance()
				NetworkBridge.inherit_damage_source(new_gas_cloud, self)
				get_parent().add_child(new_gas_cloud)
				new_gas_cloud.global_transform.origin = global_transform.origin
				NetworkBridge.n_rpc(self, "_spawn_fake_gas", [new_gas_cloud.global_transform.origin])
				NetworkBridge.n_rpc(self, "_remove")
				_remove(null)
			velocity = velocity.bounce(collision.normal) * 0.6
			angular_velocity = Vector2(velocity.x, velocity.z).length()

		if collision and t >= 200 and not player_head:
			if not stay_active:
				finished = true
				set_physics_process(false)
				physics_revision += 1
				NetworkBridge.n_rpc(self, "sync_settled_pose", [global_transform, velocity, physics_revision])
			if particle:
				particle_node.emitting = false
				particle_node.hide()
		velocity.y -= gravity * delta
	else:
		if not global_transform.is_equal_approx(lerp_transform):
			global_transform = global_transform.interpolate_with(lerp_transform, clamp(delta * 10.0, 0.0, 1.0))

func align_up(node_basis, normal)->Basis:
	var result = Basis()
	var scale = node_basis.get_scale()

	result.x = normal.cross(node_basis.z) + Vector3(1e-05, 0, 0)
	result.y = normal + Vector3(0, 1e-05, 0)
	result.z = node_basis.x.cross(normal) + Vector3(0, 0, 1e-05)
	
	result = result.orthonormalized()
	result.x *= scale.x
	result.y *= scale.y
	result.z *= scale.z

	return result

func set_grill(value):
	if grillable:
		grill = value
		NetworkBridge.n_rpc(self, "network_set_grill", [value])

remote func network_set_grill(id, recived_value):
	grill = recived_value

remote func set_hold_object(id, recived_damager):
	request_hold(id, 20 if recived_damager else 0)

remote func set_drop_object(id = null):
	request_release(id, global_transform.origin, Vector3.ZERO, Vector3.ZERO, false)

func player_use():
	if usable and not held:
		NetworkBridge.request_host(self, "request_hold", [glob.implants.arm_implant.throw_bonus])

master func request_hold(id, throw_bonus):
	if not NetworkBridge.is_world_authority() or not usable or held:
		return
	id = NetworkBridge.request_sender(id)
	var actor = NetworkBridge.get_peer_actor(id)


	if actor == null or not throw_bonus in [0, 20] or actor.global_transform.origin.distance_to(global_transform.origin) > 6.0:
		return
	for prop in get_tree().get_nodes_in_group("network_held_props"):
		if prop.holdId == id:
			return
	holder_throw_bonus = throw_bonus
	physics_revision += 1
	sync_hold_state(null, id, global_transform, Vector3.ZERO, throw_bonus > 0, false, physics_revision)
	NetworkBridge.n_rpc(self, "sync_hold_state", [id, global_transform, velocity, damager, false, physics_revision])

func release_held(position, backwards, player_velocity, kicked):
	NetworkBridge.request_host(self, "request_release", [position, backwards, player_velocity, kicked])

master func request_release(id, position, backwards, player_velocity, kicked):
	if not NetworkBridge.is_world_authority():
		return
	id = NetworkBridge.request_sender(id)
	var actor = NetworkBridge.get_peer_actor(id)
	if not held or id != holdId or actor == null:
		return
	if not InteractionPolicy.valid_release(position, actor.global_transform.origin, backwards, player_velocity, kicked):
		return
	global_transform.origin = position
	playerIgnoreId = id
	set_meta("crus_damage_source", id)
	var released_velocity = InteractionPolicy.release_velocity(kicked, backwards, player_velocity, holder_throw_bonus, mass)
	_commit_release(kicked, released_velocity)

func _commit_release(kicked, released_velocity):
	physics_revision += 1
	var throw_damager = kicked and holder_throw_bonus > 0
	sync_hold_state(null, 0, global_transform, released_velocity, throw_damager, kicked, physics_revision)
	NetworkBridge.n_rpc(self, "sync_hold_state", [0, global_transform, released_velocity, throw_damager, kicked, physics_revision])

puppet func sync_hold_state(id, holder, state_transform, state_velocity, state_damager, state_alerter, revision = 0):
	if revision < physics_revision:
		return
	physics_revision = revision
	var previous_holder = holdId
	holdId = holder
	held = holder != 0
	stay_active = held
	finished = false
	set_physics_process(true)
	t = 0
	damager = state_damager
	alerter = state_alerter
	global_transform = state_transform
	lerp_transform = state_transform
	velocity = state_velocity
	_set_hold_collision(null, held)
	if held:
		add_to_group("network_held_props")
	elif is_in_group("network_held_props"):
		remove_from_group("network_held_props")
	if holder == NetworkBridge.get_id():
		glob.player.weapon.hold(self)
	elif previous_holder == NetworkBridge.get_id() and is_instance_valid(glob.player):
		var weapon = glob.player.weapon
		if weapon.held_object == self:
			weapon.holding = false
			weapon.use_ray.remove_exception(self)

func damage(damage, collision_n, collision_p, shooter_pos):
	set_meta("crus_damage_source", NetworkBridge.damage_source_context)
	network_damage(null, damage, collision_n, collision_p, shooter_pos)

func network_damage(id, damage, collision_n, collision_p, shooter_pos):
	if NetworkBridge.n_is_network_master(self):
		if gas:
			var new_gas_cloud = gas_cloud.instance()
			NetworkBridge.inherit_damage_source(new_gas_cloud, self)
			get_parent().add_child(new_gas_cloud)
			new_gas_cloud.global_transform.origin = global_transform.origin
			NetworkBridge.n_rpc(self, "_spawn_fake_gas", [new_gas_cloud.global_transform.origin])
			NetworkBridge.n_rpc(self, "_remove")
			_remove(null)
		if damage < 3:
			return
		finished = false
		t = 0
		set_physics_process(true)

		if NetworkBridge.n_is_network_master(self):
			velocity -= collision_n * damage / mass
		if not no_rot:
			look_at((global_transform.origin - collision_n * damage + Vector3(1e-05, 0, 0)), Vector3.UP)
			rot_changed = Vector3(0, rand_range( - PI, PI), rand_range( - PI, PI))
			rot_towards_y = rotation.y
		if gun_rotation:
			angular_velocity = velocity.length()
	else:
		NetworkBridge.n_rpc(self, "network_damage", [damage, collision_n, collision_p, shooter_pos])

func set_water(a):
	if NetworkBridge.n_is_network_master(self):
		finished = false
		t = 0
		set_physics_process(true)
		water = a
		velocity *= 0.5
		velocity.y = 0

func get_type():
	return type;

func physics_object():
	pass

puppet func sync_settled_pose(id, state_transform, state_velocity, revision):
	if revision < physics_revision:
		return
	physics_revision = revision
	global_transform = state_transform
	lerp_transform = state_transform
	velocity = state_velocity
	finished = true
	set_physics_process(false)
