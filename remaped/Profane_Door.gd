extends KinematicBody

const DoorPolicy = preload("res://MOD_CONTENT/CruS Online/SpiritualDoorPolicy.gd")
var door_revision = 0

onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

var PARTICLE = preload("res://Entities/Particles/Destruction_Particle.tscn")

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
var type = 1
var audio_player

var isDestroyed = false

func _ready():
	NetworkBridge.register_rpcs(self, [
		["_get_transform", NetworkBridge.PERMISSION.ALL],
		["request_use", NetworkBridge.PERMISSION.ALL],
		["sync_door", NetworkBridge.PERMISSION.SERVER],
		["_set_transform", NetworkBridge.PERMISSION.SERVER]
	])

	set_process(false)
	set_collision_layer_bit(8, 1)
	for child in get_children():
		if child is MeshInstance:
			mesh_instance = child
		if child is CollisionShape:
			collision_shape = child
	var t = mesh_instance.transform
	
	if mesh_instance.get_aabb().size.x > mesh_instance.get_aabb().size.z:
		global_transform.origin.x -= mesh_instance.get_aabb().position.x
		global_transform.origin.z -= mesh_instance.get_aabb().position.z + mesh_instance.get_aabb().size.z * 0.5
		t = t.translated(Vector3(mesh_instance.get_aabb().position.x, 0, mesh_instance.get_aabb().position.z + mesh_instance.get_aabb().size.z * 0.5))
	else :
		global_transform.origin.x -= mesh_instance.get_aabb().position.x + mesh_instance.get_aabb().size.x * 0.5
		global_transform.origin.z -= mesh_instance.get_aabb().position.z
		t = t.translated(Vector3(mesh_instance.get_aabb().position.x + mesh_instance.get_aabb().size.x * 0.5, 0, mesh_instance.get_aabb().position.z))
	
	mesh_instance.transform = t
	collision_shape.transform = t

	audio_player = AudioStreamPlayer3D.new()
	get_parent().call_deferred("add_child", audio_player)
	yield (get_tree(), "idle_frame")
	audio_player.global_transform.origin = global_transform.origin
	audio_player.stream = load("res://Sfx/Environment/doorkick.wav")
	audio_player.unit_size = 10
	audio_player.unit_db = 4
	audio_player.max_db = 4
	audio_player.pitch_scale = 0.6

	if NetworkBridge.check_connection() and not NetworkBridge.is_world_authority():
		NetworkBridge.request_host(self, "_get_transform")

master func _get_transform(id):
	if not NetworkBridge.is_world_authority():
		return
	id = NetworkBridge.request_sender(id)
	if NetworkBridge.get_peer_actor(id) != null:
		NetworkBridge.n_rpc_id(self, id, "sync_door", [global_transform, open, stop, door_revision])

func _publish_door():
	if NetworkBridge.check_connection():
		NetworkBridge.n_rpc(self, "sync_door", [global_transform, open, stop, door_revision])

puppet func sync_door(_id, pose, opened, stopped, revision):
	if typeof(pose) != TYPE_TRANSFORM or typeof(opened) != TYPE_BOOL or typeof(stopped) != TYPE_BOOL or typeof(revision) != TYPE_INT or revision < door_revision:
		return
	door_revision = revision
	global_transform = pose
	open = opened
	stop = stopped

puppet func _set_transform(_id, pose, revision):
	if typeof(revision) == TYPE_INT and revision == door_revision and not stop:
		global_transform = pose

func _physics_process(delta):
	if not NetworkBridge.is_world_authority() or stop:
		return
	var step = min(rotation_speed * delta, deg2rad(90 - rotation_counter))
	rotation.y += -step if open else step
	rotation_counter += rad2deg(step)
	if rotation_counter >= 89.999:
		rotation_counter = 0
		stop = true
		door_revision += 1
		_publish_door()
	elif NetworkBridge.check_connection():
		NetworkBridge.n_rpc_unreliable(self, "_set_transform", [global_transform, door_revision])

func get_type():
	return type;

func player_use():
	if Global.husk_mode:
		NetworkBridge.request_host(self, "request_use", [DoorPolicy.capture(Global)])
	else:
		Global.player.UI.notify("It repulses you.", Color(0.5, 0.5, 0))
		Global.player.player_velocity -= (global_transform.origin - Global.player.global_transform.origin).normalized() * 5

master func request_use(id, spiritual_state):
	if not NetworkBridge.is_world_authority():
		return
	id = NetworkBridge.request_sender(id)
	var actor = NetworkBridge.get_peer_actor(id)
	if actor == null or not DoorPolicy.allows(spiritual_state, "husk_mode", actor.global_transform.origin, global_transform.origin):
		return
	stop = not stop
	open = not open
	door_revision += 1
	_publish_door()
