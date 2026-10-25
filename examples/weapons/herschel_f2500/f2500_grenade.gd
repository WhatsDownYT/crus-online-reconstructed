extends KinematicBody

var velocity = Vector3.ZERO
var lifetime = 0.0
var detonated = false
var NetworkBridge

func _ready():
	NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")
	NetworkBridge.register_rpcs(self, [["detonate", NetworkBridge.PERMISSION.SERVER]])
	set_collision_layer_bit(0, false)
	set_collision_layer_bit(6, true)

func _physics_process(delta):
	if detonated:
		return
	lifetime += delta
	if lifetime > 8.0:
		if NetworkBridge.n_is_network_master(self):
			_explode(global_transform.origin)
		return
	velocity.y -= 15.0 * delta
	var hit = move_and_collide(velocity * delta)
	if hit and NetworkBridge.n_is_network_master(self):
		_explode(hit.position)

func _explode(point):
	if detonated:
		return
	detonate(null, point)
	NetworkBridge.n_rpc(self, "detonate", [point])

puppet func detonate(_sender, point):
	if detonated:
		return
	detonated = true
	var blast = preload("res://Entities/Bullets/Explosion.tscn").instance()
	NetworkBridge.inherit_damage_source(blast, self)
	get_parent().add_child(blast)
	blast.global_transform.origin = point
	blast.damage = 500
	if NetworkBridge.n_is_network_master(self):
		_shrapnel(point)
	queue_free()

func _shrapnel(point):
	var space = get_world().direct_space_state
	for _fragment in range(32):
		var direction = Vector3(rand_range(-1, 1), rand_range(-0.5, 1), rand_range(-1, 1)).normalized()
		var hit = space.intersect_ray(point, point + direction * 24.0, [self])
		if hit.empty():
			continue
		var target = hit.collider
		if target.has_method("player_damage"):
			NetworkBridge.apply_damage(self, target, "player_damage", [25, direction, hit.position, point, "explosion"])
		elif target.has_method("damage"):
			NetworkBridge.apply_damage(self, target, "damage", [25, direction, hit.position, point])
