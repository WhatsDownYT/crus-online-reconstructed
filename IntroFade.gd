extends Node

var player
var started_msec = 0

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	started_msec = OS.get_ticks_msec()

func _process(_delta):
	if not is_instance_valid(player) or not is_instance_valid(player.shader_screen):
		queue_free()
		return
	player.amp = 1.0 - float(OS.get_ticks_msec() - started_msec) / 2000.0
	if player.amp <= 0.0:
		player.amp = -0.001
		if player.multiplayer_sedative_time <= 0.0:
			player.shader_screen.material.set_shader_param("intro", false)
			player.shader_screen.material.set_shader_param("amplitude", 0.0)
		player.set_process_input(true)
		player.start_flag = true
		queue_free()
	elif player.multiplayer_sedative_time <= 0.0:
		player.shader_screen.material.set_shader_param("amplitude", player.amp)
