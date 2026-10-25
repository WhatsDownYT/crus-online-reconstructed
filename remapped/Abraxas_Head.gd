extends KinematicBody

onready var Multiplayer = Global.get_node("Multiplayer")
onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

var type = 1
var active = false
export  var health = 10
var destroyed = false

func _ready():
	set_meta("counterop_npc", true)
	NetworkBridge.register_rpcs(self, [
		["died", NetworkBridge.PERMISSION.SERVER],
		["network_damage", NetworkBridge.PERMISSION.ALL]
	])

puppet func died(id):
	get_parent().get_node("Sphere").hide()
	get_parent().get_node("Particle").show()

func damage(dmg, nrml, pos, shoot_pos):
	network_damage(null, dmg, nrml, pos, shoot_pos)

master func network_damage(id, dmg, nrml, pos, shoot_pos):
	if NetworkBridge.n_is_network_master(self):
		var source_peer = NetworkBridge.request_sender(id) if id != null else NetworkBridge.damage_source_context
		if not Multiplayer.CounterOp.can_damage_npc(source_peer, self):
			return
		if not active:
			return 
		health -= dmg
		if health <= 0:
			destroyed = true
			died(null)
			NetworkBridge.n_rpc(self, "died")
	else:
		NetworkBridge.n_rpc(self, "network_damage", [dmg, nrml, pos, shoot_pos])

func get_type():
	return type
