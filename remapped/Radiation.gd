extends Particles

onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

export  var damage = 0.4

func _physics_process(delta):
	if NetworkBridge.n_is_network_master(self):
		for body in $Area.get_overlapping_bodies():
			if body == Global.player and Global.death:
				return 
			if body.has_method("player_damage"):
				NetworkBridge.apply_damage(self, body, "player_damage", [damage, Vector3.ZERO, body.global_transform.origin, global_transform.origin, "radiation"])
			elif body.has_method("damage"):
				NetworkBridge.apply_damage(self, body, "damage", [damage, Vector3.ZERO, body.global_transform.origin, global_transform.origin])
