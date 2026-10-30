extends KinematicBody

onready var Multiplayer = Global.get_node("Multiplayer")
onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")
enum I {GOLEM, WEAPON, MONEY}
export(I) var index = I.GOLEM
export var line = "Triagon 01 is gone. (Golem Exosystem Received)"
export var line2 = "I bestow upon you power."
var type = 1
var health = 2500
var death_flag = false
var follow_speed = 0.02
var active = false
var destroyed = false
var disabled = false
var look_towards = Vector3.ZERO
var endpoint = Vector3.ZERO
var beam_hit = false
var sync_elapsed = 0.0
var previously_dead = false
var death_pose = Transform()
var death_gib_name = ""
var gib = preload("res://Entities/Physics_Objects/Snake_Gib.tscn")
onready var laser = $Laser
onready var particle = $Particles

func _ready():
	add_to_group("admin_npcs")
	set_meta("counterop_npc", true)
	NetworkBridge.register_rpcs(self, [["network_damage", NetworkBridge.PERMISSION.ALL], ["request_state", NetworkBridge.PERMISSION.ALL], ["sync_triagon_attack", NetworkBridge.PERMISSION.SERVER], ["sync_death", NetworkBridge.PERMISSION.SERVER], ["sync_removed", NetworkBridge.PERMISSION.SERVER]])
	Multiplayer.connect("scene_loaded", self, "_scene_ready")
	previously_dead = NetworkBridge.is_world_authority() and Global.DEAD_CIVS.has(line)
	if previously_dead or Multiplayer.Deathmatch.is_active():
		get_parent().hide()
	look_towards = global_transform.origin

func _scene_ready():
	if NetworkBridge.is_world_authority():
		if previously_dead or Multiplayer.Deathmatch.is_active():
			NetworkBridge.n_rpc(self, "sync_removed")
			sync_removed(null)
		else:
			_publish()
	else:
		NetworkBridge.request_host(self, "request_state", [])

master func request_state(_id):
	if not NetworkBridge.is_world_authority(): return
	if previously_dead or Multiplayer.Deathmatch.is_active():
		NetworkBridge.n_rpc(self, "sync_removed")
	elif death_flag:
		NetworkBridge.n_rpc(self, "sync_death", [death_pose, death_gib_name])
	else:
		_publish()

func _physics_process(delta):
	if not NetworkBridge.is_world_authority() or death_flag or previously_dead: return
	var target = null
	var distance = INF
	for actor in Multiplayer.get_alive_actors(self):
		if not is_instance_valid(actor): continue
		var candidate = global_transform.origin.distance_squared_to(actor.global_transform.origin)
		if candidate < distance:
			distance = candidate
			target = actor
	if target != null:
		look_towards = look_towards.linear_interpolate(target.global_transform.origin + Vector3.UP * 0.8, 1.0 - pow(1.0 - follow_speed, delta * 60.0))
	beam_hit = false
	if active and not disabled and target != null:
		var direction = (look_towards - global_transform.origin).normalized()
		var result = get_world().direct_space_state.intersect_ray(global_transform.origin, global_transform.origin + direction * 1000, [self])
		endpoint = global_transform.origin + direction * 800
		if not result.empty():
			endpoint = result.position
			beam_hit = true
			if result.collider == Global.player or NetworkBridge.damage_target_id(result.collider) > 0:
				NetworkBridge.apply_npc_damage(self, result.collider, "damage", [20.0 * delta * 60.0, result.normal, result.position, global_transform.origin])
	sync_elapsed += delta
	if sync_elapsed >= 0.1:
		sync_elapsed = 0.0
		_publish()

func _publish():
	if NetworkBridge.check_connection():
		NetworkBridge.n_rpc_unreliable(self, "sync_triagon_attack", [active, disabled, health, endpoint, beam_hit])

puppet func sync_triagon_attack(_id, enabled, off, hp, end, hit):
	active = enabled
	disabled = off
	health = hp
	endpoint = end
	beam_hit = hit

func _process(delta):
	particle.visible = active and not disabled and beam_hit and not death_flag
	laser.visible = active and not disabled and not death_flag
	if not laser.visible: return
	particle.global_transform.origin = endpoint
	if endpoint.distance_squared_to(global_transform.origin) > 0.0001:
		laser.look_at(endpoint, Vector3.UP)
	laser.scale.z = lerp(laser.scale.z, global_transform.origin.distance_to(endpoint) * 0.5, min(1.0, delta * 12.0))

func damage(dmg, nrml, pos, shoot_pos):
	if NetworkBridge.is_world_authority(): network_damage(null, dmg, nrml, pos, shoot_pos)
	else: NetworkBridge.request_host(self, "network_damage", [dmg, nrml, pos, shoot_pos])

master func network_damage(id, dmg, nrml, pos, shoot_pos):
	if not NetworkBridge.is_world_authority() or death_flag: return
	var source = NetworkBridge.request_sender(id) if id != null else NetworkBridge.damage_source_context
	if not Multiplayer.CounterOp.can_damage_npc(source, self): return
	active = true
	health -= dmg
	if health <= 0:
		var pose = global_transform
		var gib_name = "TriagonHead_" + str(get_path()).md5_text().substr(0, 10)
		NetworkBridge.n_rpc(self, "sync_death", [pose, gib_name])
		sync_death(null, pose, gib_name)

puppet func sync_death(_id, pose, gib_name):
	if death_flag: return
	death_flag = true
	death_pose = pose
	death_gib_name = gib_name
	if not Global.current_scene.has_node(gib_name):
		var head = gib.instance()
		head.name = gib_name
		Global.current_scene.add_child(head)
		head.global_transform = pose
	if not Global.DEAD_CIVS.has(line):
		if index == I.GOLEM and not Global.implants.purchased_implants.has("CSIJ Level VI Golem Exosystem"):
			Global.implants.purchased_implants.append("CSIJ Level VI Golem Exosystem")
		elif index == I.MONEY: Global.money += 1000000
		elif index == I.WEAPON: Global.WEAPONS_UNLOCKED[Global.player.weapon.W_SHOCK] = true
		Global.DEAD_CIVS.append(line)
		Global.player.UI.notify(line, Color(0, 1, 0))
		Global.player.UI.message(line2, true)
		Global.save_game()
	_hide_head()

puppet func sync_removed(_id):
	death_flag = true
	_hide_head()

func _hide_head():
	get_parent().hide()
	laser.hide()
	particle.hide()
	for child in get_children():
		if child is CollisionShape: child.set_deferred("disabled", true)
	set_process(false)
	set_physics_process(false)

func get_type():
	return type
