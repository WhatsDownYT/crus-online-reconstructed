extends Spatial

onready var bridge = Global.get_node("Multiplayer/NetworkBridge")
var elapsed = 0.0

func _ready():
	bridge.register_rpcs(self, [["sync_triagon_pose", bridge.PERMISSION.SERVER]])
	$snake/AnimationPlayer.play("Idle", -1, 0.2)

func _physics_process(delta):
	if not bridge.is_world_authority(): return
	var closest = null
	var distance = INF
	for actor in Global.get_node("Multiplayer").get_alive_actors(self):
		if not is_instance_valid(actor): continue
		var candidate = global_transform.origin.distance_squared_to(actor.global_transform.origin)
		if candidate < distance:
			distance = candidate
			closest = actor
	if closest != null and distance > 0.0001:
		look_at(closest.global_transform.origin, Vector3.UP)
	elapsed += delta
	if elapsed >= 0.1 and bridge.check_connection():
		elapsed = 0.0
		bridge.n_rpc_unreliable(self, "sync_triagon_pose", [global_transform])

puppet func sync_triagon_pose(_id, pose):
	global_transform = pose
