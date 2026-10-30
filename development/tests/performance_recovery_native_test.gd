extends Node
var failures = 0
func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")
func load_level(index):
	Global.CURRENT_LEVEL = index
	Global.goto_scene(Global.LEVELS[index])
	while Global.loader != null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != Global.LEVELS[index]:
		yield(get_tree().create_timer(0.1), "timeout")
	yield(get_tree().create_timer(1), "timeout")
	get_tree().paused = false
	Global.menu.in_game = true
	Global.menu.hide()
	Global.player.global_transform.origin = Vector3(0, 1000, 0)
	Global.player.health = 10000
func sample(label):
	print("RECOVERY_SAMPLE ", label, " nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " physics=", Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), " process_ms=", Performance.get_monitor(Performance.TIME_PROCESS)*1000, " physics_ms=", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000, " clouds=", get_tree().get_nodes_in_group("acr_clouds").size(), " audio_buses=", AudioServer.bus_count)
func run():
	yield(get_tree().create_timer(12), "timeout")
	Global.select_save_slot(1)
	yield(load_level(1), "completed")
	sample("initial-pharma")
	var mp = Global.get_node("Multiplayer")
	mp.show_connection_screen()
	if not mp.get_node("SyncLoad").visible or mp.get_node("SyncLoad/Center/Label").text != "Connecting": failures += 1
	mp.hide_connection_screen()
	if mp.get_node("SyncLoad").visible: failures += 1
	for cycle in range(2):
		yield(load_level(2), "completed")
		var cloud_scene = load("res://Entities/Bullets/Radiation.tscn")
		for index in range(180):
			var cloud = cloud_scene.instance()
			mp.NetworkBridge.inherit_damage_source(cloud, Global.player)
			Global.current_scene.add_child(cloud)
			cloud.global_transform.origin = Vector3(index%10, 900, index/10)
			if index%30 == 0: yield(get_tree(), "idle_frame")
		yield(get_tree().create_timer(2), "timeout")
		sample("paradise-acr-"+str(cycle))
		yield(load_level(1), "completed")
		yield(get_tree().create_timer(2), "timeout")
		sample("recovered-pharma-"+str(cycle))
		if not get_tree().get_nodes_in_group("acr_clouds").empty(): failures += 1
		if not mp.SteamNetwork._census_pending.empty(): failures += 1
	print("PERFORMANCE_RECOVERY_RESULT failures=", failures)
	get_tree().quit()
