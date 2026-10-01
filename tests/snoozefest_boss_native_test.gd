extends Node

var failures = 0
var mp

func check(value, label):
	print("SNOOZE_CHECK host=", HOST, " ", label, "=", value)
	if not value:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

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
		Global.hope_discarded = true
		Global.hell_discovered = true
		Global.DEAD_CIVS.clear()
		mp.goto_scene_host(Global.LEVELS[0])
	while Global.loader != null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != Global.LEVELS[0] or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1), "timeout")
	yield(get_tree().create_timer(2), "timeout")
	var boss = Global.current_scene.get_node_or_null("Lifeman2")
	check(boss != null, "CSHQ target spawned")
	if boss != null:
		print("SNOOZE_STATE host=", HOST, " children=", boss.get_children(), " dead_civs=", Global.DEAD_CIVS)
		check(not boss.armored and not boss.poison_death, "target is not immune")
		if HOST:
			boss.get_node("Body/Collisions/Torso").tranquilize(true)
			check(not boss.tranqtimer.is_stopped(), "dart starts target sleep timer")
		yield(get_tree().create_timer(3), "timeout")
		check(boss.get_node("Body").tranq, "target falls asleep")
	print("SNOOZE_RESULT host=", HOST, " failures=", failures)
	get_tree().quit(1 if failures else 0)
