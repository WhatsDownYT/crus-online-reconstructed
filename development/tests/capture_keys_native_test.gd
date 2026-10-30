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
	Global.menu.in_game = true
	var capture = Global.get_node("DebugCapture")
	capture.active_player = p
	var marker = MeshInstance.new()
	marker.name = "Objective_Indicator"
	Global.current_scene.add_child(marker)
	p.weapon.show()
	var event = InputEventKey.new()
	event.pressed = true
	event.scancode = KEY_F2
	capture._input(event)
	if not capture.ui_hidden or not p.weapon.visible or marker.visible: failures += 1
	event.scancode = KEY_F3
	capture._input(event)
	if not capture.view_hidden or p.weapon.visible: failures += 1
	event.scancode = KEY_F2
	capture._input(event)
	if capture.ui_hidden or not marker.visible or p.weapon.visible: failures += 1
	event.scancode = KEY_F3
	capture._input(event)
	if capture.view_hidden or not p.weapon.visible: failures += 1
	print("CAPTURE_KEYS_RESULT failures=", failures)
	get_tree().quit()
