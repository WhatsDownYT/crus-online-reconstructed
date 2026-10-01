extends Node

var failures = 0
var mp

func check(value, label):
	print("TARGET_CHECK host=", HOST, " ", label, "=", value)
	if not value:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func wait_for_level(epoch):
	while mp.SteamNetwork.scene_epoch < epoch or Global.loader != null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != Global.LEVELS[0] or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1), "timeout")
	yield(get_tree().create_timer(2.0), "timeout")

func run():
	yield(get_tree().create_timer(6), "timeout")
	mp = Global.get_node("Multiplayer")
	mp.NetworkBridge.set_mode(mp.NetworkBridge.MULTIPLAYER_TYPE.LAN)
	if HOST:
		mp.config.hostPort = PORT
		mp.host_server()
	else:
		mp.join_to_server("127.0.0.1", PORT)
	while mp.players.size() < 2:
		yield(get_tree().create_timer(0.1), "timeout")
	if HOST:
		Global.hope_discarded = false
		Global.hell_discovered = false
		mp.goto_scene_host(Global.LEVELS[0])
	yield(wait_for_level(2), "completed")
	check(mp.get_node("DiscordPresence").mission_counter() == "Targets: 0/0", "CSHQ without Hope Eradicated has no target")
	if HOST:
		Global.hope_discarded = true
		Global.hell_discovered = true
		mp.goto_scene_host(Global.LEVELS[0])
	yield(wait_for_level(3), "completed")
	check(mp.get_node("DiscordPresence").mission_counter() == "Targets: 1/1", "CSHQ with Hope Eradicated has one target")
	print("TARGET_RESULT host=", HOST, " failures=", failures)
	get_tree().quit(1 if failures else 0)
