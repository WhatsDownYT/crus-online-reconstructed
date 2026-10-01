extends Node

var failures = 0

func check(value, label):
	print("IMMORTAL_CHECK host=", HOST, " ", label, "=", value)
	if not value:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6), "timeout")
	var mp = Global.get_node("Multiplayer")
	mp.NetworkBridge.set_mode(mp.NetworkBridge.MULTIPLAYER_TYPE.LAN)
	if HOST:
		mp.config.hostPort = PORT
		mp.host_server()
	else:
		mp.join_to_server("127.0.0.1", PORT)
	while mp.players.size() < 2:
		yield(get_tree().create_timer(0.1), "timeout")
	var level = Global.LEVELS[14]
	if HOST:
		mp.goto_scene_host(level)
	while Global.loader != null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != level or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1), "timeout")
	yield(get_tree().create_timer(2), "timeout")
	if HOST:
		var registered = 0
		var immortal = 0
		var pending = [Global.current_scene]
		while not pending.empty():
			var node = pending.pop_back()
			pending.append_array(node.get_children())
			if not ("immortal" in node and "population_registered" in node):
				continue
			if node.immortal and node.enabled:
				immortal += 1
				check(not node.population_registered, "immortal is excluded")
			if node.population_registered and not node.civilian:
				registered += 1
		check(immortal > 0, "level has immortal enemies")
		check(Global.enemy_count_total == registered, "end counter totals only killable enemies")
	print("IMMORTAL_RESULT host=", HOST, " failures=", failures)
	get_tree().quit(1 if failures else 0)
