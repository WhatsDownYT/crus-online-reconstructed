extends Area

onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

export  var damage = 50
export  var gas = false
export  var sleep = false
export  var piercing = true
var c_shape
var particle

var gas_timer = 0

func _delete():
	queue_free()

func _ready():
	particle = $Particle
	c_shape = $CollisionShape
	particle.emitting = true
	
func _physics_process(delta):
	if NetworkBridge.n_is_network_master(self):
		if particle.emitting == false:
			if not gas:
				c_shape.disabled = true
				c_shape.visible = false
			else :
				gas_timer += delta
				if gas_timer >= 3:
					_delete()
		if gas and not sleep:
			for overlap_body in get_overlapping_bodies():
				if overlap_body.has_method("player_damage"):
					NetworkBridge.apply_damage(self, overlap_body, "player_damage", [damage, Vector3.ZERO, overlap_body.global_transform.origin, global_transform.origin, "gas"])
				elif overlap_body.has_method("damage"):
					NetworkBridge.apply_damage(self, overlap_body, "damage", [damage, Vector3.ZERO, overlap_body.global_transform.origin, global_transform.origin])

func _on_Explosion_area_entered(area):
	if NetworkBridge.n_is_network_master(self):
		do_damage(area)

func _on_Explosion_body_entered(body):
	if NetworkBridge.n_is_network_master(self):
		do_damage(body)
		if sleep and body.has_method("tranquilize"):
			var source_id = NetworkBridge.damage_source_id(self)
			var target_id = NetworkBridge.damage_target_id(body)
			var multiplayer = Global.get_node_or_null("Multiplayer")
			var multiplayer_sedative = multiplayer != null and source_id > 0 and target_id > 0 and multiplayer.peer_has_implant_flag(source_id, "multiplayer_sedative")
			var other_player = multiplayer != null and NetworkBridge.check_connection() and multiplayer.players.has(source_id) and target_id > 0 and source_id != target_id
			if other_player or multiplayer_sedative:
				var sedative_immune = source_id == target_id or multiplayer.peer_has_implant_flag(target_id, "sedative_immune")
				if multiplayer_sedative and not sedative_immune and NetworkBridge.damage_allowed(source_id, target_id, self):
					if body == Global.player:
						Global.player.set_multiplayer_sedative(10.0)
					elif body.has_method("multiplayer_sedative"):
						body.multiplayer_sedative(source_id)
			else:
				NetworkBridge.apply_damage(self, body, "tranquilize", [true])

func do_damage(body):
	if not NetworkBridge.damage_allowed(NetworkBridge.damage_source_id(self), NetworkBridge.damage_target_id(body)):
		return
	if gas:
		return 
	var state = get_world().direct_space_state
	var result = state.intersect_ray(global_transform.origin, body.global_transform.origin, [self])
	if result:
		if result.collider.get_class() == "StaticBody":
			if result.collider.has_method("damage"):
				return 
	if body.has_method("damage"):
		if body == Global.player and Global.implants.torso_implant.explosive_shield:
			Global.player.player_velocity -= (global_transform.origin - body.global_transform.origin).normalized() * damage * 0.05
			return 
		NetworkBridge.apply_damage(self, body, "damage", [damage, (global_transform.origin - body.global_transform.origin).normalized(), body.global_transform.origin, global_transform.origin])
	if body.has_method("piercing_damage") and piercing:
		NetworkBridge.apply_damage(self, body, "piercing_damage", [damage, (global_transform.origin - body.global_transform.origin).normalized(), body.global_transform.origin, global_transform.origin])
