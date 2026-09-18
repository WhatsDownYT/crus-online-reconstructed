extends KinematicBody

const DoorPolicy = preload("res://MOD_CONTENT/CruS Online/SpiritualDoorPolicy.gd")
var isDestroyed = false

onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

var GIB = preload("res://Entities/Physics_Objects/Chest_Gib.tscn")

export  var door_health = 100
export  var rotation_speed = 2
var open = false
var stop = true
var initrot = rotation
var rotation_counter = 0
var mesh_instance
var collision_shape
var collision = false
var found_overlap
var type = 0
var audio_player

func _ready():
	NetworkBridge.register_rpcs(self, [
		["request_use", NetworkBridge.PERMISSION.ALL],
		["_get_state", NetworkBridge.PERMISSION.ALL],
		["remove_on_ready", NetworkBridge.PERMISSION.SERVER],
		["remove", NetworkBridge.PERMISSION.SERVER],
		["spawn_gib", NetworkBridge.PERMISSION.SERVER]
	])
	
	set_collision_layer_bit(8, 1)
	audio_player = AudioStreamPlayer3D.new()
	get_parent().call_deferred("add_child", audio_player)
	yield (get_tree(), "idle_frame")
	audio_player.global_transform.origin = global_transform.origin
	audio_player.stream = load("res://Sfx/Flesh/gibbing_3.wav")
	audio_player.unit_size = 10
	audio_player.unit_db = 4
	audio_player.max_db = 4
	audio_player.pitch_scale = 0.6
	if NetworkBridge.check_connection() and not NetworkBridge.is_world_authority():
		NetworkBridge.request_host(self, "_get_state")

func get_type():
	return type

func player_use():
	if not Global.hope_discarded:
		Global.player.UI.notify("zvhvhivj jidv ijvdkjaeui djvhduhekj vduihkeu", Color(1, 0, 0))
	else:
		NetworkBridge.request_host(self, "request_use", [DoorPolicy.capture(Global)])

master func request_use(id, spiritual_state):
	if not NetworkBridge.is_world_authority() or isDestroyed:
		return
	id = NetworkBridge.request_sender(id)
	var actor = NetworkBridge.get_peer_actor(id)
	if actor == null or not DoorPolicy.allows(spiritual_state, "hope_discarded", actor.global_transform.origin, global_transform.origin):
		return

	isDestroyed = true
	for i in range(10):
		var new_gib = GIB.instance()
		new_gib.name = new_gib.name + "#" + str(new_gib.get_instance_id())
		get_parent().add_child(new_gib)
		new_gib.global_transform.origin = global_transform.origin
		new_gib.velocity = Vector3.FORWARD.rotated(Vector3.UP, rand_range(-PI, PI))
		if NetworkBridge.check_connection():
			NetworkBridge.n_rpc(self, "spawn_gib", [new_gib.name, new_gib.global_transform, new_gib.velocity])
	remove(null)
	if NetworkBridge.check_connection():
		NetworkBridge.n_rpc(self, "remove")

master func _get_state(id):
	if not NetworkBridge.is_world_authority() or not isDestroyed:
		return
	id = NetworkBridge.request_sender(id)
	if NetworkBridge.get_peer_actor(id) != null:
		NetworkBridge.n_rpc_id(self, id, "remove_on_ready")

puppet func remove_on_ready(_id):
	isDestroyed = true
	collision_layer = 0
	collision_mask = 0
	hide()

puppet func remove(id):
	remove_on_ready(id)
	if is_instance_valid(audio_player):
		audio_player.play()

puppet func spawn_gib(_id, received_name, pose, initial_velocity):
	if typeof(received_name) != TYPE_STRING or typeof(pose) != TYPE_TRANSFORM or typeof(initial_velocity) != TYPE_VECTOR3:
		return
	if received_name.empty() or received_name.find("/") >= 0 or received_name.find(":") >= 0 or get_parent().has_node(NodePath(received_name)):
		return
	var new_gib = GIB.instance()

	new_gib.name = received_name
	get_parent().add_child(new_gib)
	new_gib.global_transform = pose
	new_gib.velocity = initial_velocity
