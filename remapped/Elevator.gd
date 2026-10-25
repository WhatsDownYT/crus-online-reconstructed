extends KinematicBody

onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

var stopped = true
var speed = - 2
var initpos = true
var last_pos
var col = false
var mesh_instance:MeshInstance
var collision_area:Area
var collision_object:CollisionShape
var bell_audio:AudioStreamPlayer3D
var move_audio:AudioStreamPlayer3D

func _ready():
	NetworkBridge.register_rpcs(self, [
		["sync_state", NetworkBridge.PERMISSION.SERVER],
		["network_use", NetworkBridge.PERMISSION.ALL]
	])
	
	NetworkBridge.register_rset(self, "global_transform", NetworkBridge.PERMISSION.SERVER)
	rset_config("global_transform",MultiplayerAPI.RPC_MODE_PUPPET)
	
	for child in get_children():
		if child is MeshInstance:
			mesh_instance = child
	set_collision_mask_bit(9, 1)
	set_collision_mask_bit(8, 1)
	set_collision_layer_bit(8, 1)
	set_collision_mask_bit(0, 0)
	bell_audio = AudioStreamPlayer3D.new()
	add_child(bell_audio)
	bell_audio.unit_size = 10
	bell_audio.unit_db = 3
	bell_audio.global_transform.origin = global_transform.origin
	move_audio = bell_audio.duplicate()
	add_child(move_audio)
	move_audio.unit_db = 2
	bell_audio.stream = load("res://Sfx/Environment/Elevator_Bell.wav")
	move_audio.stream = load("res://Sfx/Environment/Elevator_Move.wav")

func _process(delta):
	if not NetworkBridge.check_connection() or NetworkBridge.is_world_authority():
		last_pos = global_transform.origin
		if not stopped:
			if not move_audio.playing:
				move_audio.play()
			translate(Vector3(0, speed * delta, 0))
			if NetworkBridge.check_connection():
				NetworkBridge.n_rset_unreliable(self, "global_transform", global_transform)



func stop():
	if not NetworkBridge.check_connection() or NetworkBridge.is_world_authority():
		stopped = true
		initpos = not initpos
		speed = - speed
		bell_audio.play()
		move_audio.stop()
		_publish_state()

func use():
	network_use(null)
	
master func network_use(id):
	if not NetworkBridge.check_connection() or NetworkBridge.is_world_authority():
		stopped = false
		_publish_state()
	else:
		NetworkBridge.n_rpc(self, "network_use")

func _publish_state():
	if NetworkBridge.check_connection():
		NetworkBridge.n_rpc(self, "sync_state", [global_transform, stopped, speed, initpos])

puppet func sync_state(id, state_transform, state_stopped, state_speed, state_initpos):
	global_transform = state_transform
	stopped = state_stopped
	speed = state_speed
	initpos = state_initpos
	if stopped:
		bell_audio.play()
		move_audio.stop()
	elif not move_audio.playing:
		move_audio.play()
