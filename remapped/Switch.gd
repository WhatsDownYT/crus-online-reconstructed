extends Area

onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

var button_audio
var error_audio
var overlap_exists = false

func _ready():
	NetworkBridge.register_rpcs(self, [["request_use", NetworkBridge.PERMISSION.ALL], ["play_result", NetworkBridge.PERMISSION.SERVER]])
	set_collision_layer_bit(8, 1)
	button_audio = AudioStreamPlayer3D.new()
	add_child(button_audio)
	button_audio.global_transform.origin = global_transform.origin
	button_audio.unit_size = 5
	button_audio.unit_db = 2
	button_audio.pitch_scale = 0.7
	button_audio.stream = load("res://Sfx/Environment/Elevator_Bell.wav")
	error_audio = AudioStreamPlayer3D.new()
	add_child(error_audio)
	error_audio.global_transform.origin = global_transform.origin
	error_audio.unit_size = 5
	error_audio.unit_db = 2
	error_audio.stream = load("res://Sfx/UI/UI_selection.wav")

func use():
	NetworkBridge.request_host(self, "request_use")

master func request_use(id):
	if not NetworkBridge.is_world_authority():
		return
	var actor = NetworkBridge.get_peer_actor(NetworkBridge.request_sender(id))
	if NetworkBridge.check_connection() and (actor == null or actor.global_transform.origin.distance_to(global_transform.origin) > 8.0):
		return
	overlap_exists = false
	var overlaps = get_overlapping_bodies()
	for overlap in overlaps:
		if overlap.has_method("use"):
			overlap.use()
			overlap_exists = true
		if overlap.has_method("switch_use"):
			overlap.switch_use()
			overlap_exists = true
	play_result(null, overlap_exists)
	NetworkBridge.n_rpc(self, "play_result", [overlap_exists])
	overlap_exists = false

puppet func play_result(id, success):
	if success:
		button_audio.play()
	else:
		error_audio.play()
