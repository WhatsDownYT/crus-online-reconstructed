extends Node
var failures = 0
func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")
func run():
	yield(get_tree().create_timer(12), "timeout")
	Global.select_save_slot(1)
	Global.CURRENT_LEVEL = 1
	Global.goto_scene(Global.LEVELS[1])
	while Global.loader != null or not is_instance_valid(Global.player):
		yield(get_tree(), "idle_frame")
	yield(get_tree().create_timer(2), "timeout")
	var p = Global.player
	p.set_process(false)
	p.set_physics_process(false)
	p.start_flag = true
	p.global_transform.origin = Vector3(0, 1000, 0)
	Global.menu.get_node("Level_Info_Grid").show()
	get_tree().paused = true
	p.instadie(100, Vector3.UP, p.global_transform.origin, Vector3.ZERO)
	yield(get_tree().create_timer(0.1), "timeout")
	var head = p.player_view.get_parent()
	var before = head.global_transform.origin
	if get_tree().paused or Global.menu.get_node("Level_Info_Grid").visible:
		failures += 1
	yield(get_tree().create_timer(0.3), "timeout")
	if head.get("player_head") != true or head.global_transform.origin.is_equal_approx(before):
		failures += 1
	print("OFFLINE_GIB_RESULT failures=", failures)
	get_tree().quit()
