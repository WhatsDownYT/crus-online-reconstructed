extends Control

onready var NetworkBridge = $"../NetworkBridge"

onready var parent = get_parent()

func _ready():
	get_viewport().connect("size_changed", self, "_layout_menu")
	_layout_menu()
	hide()
	set_process_input(false)

func hide_menu(type = null):
	hide()
	get_parent().Hint.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	Global.player.set_process(true)
	Global.player.set_physics_process(true)
	Global.player.set_process_input(true)
	Global.player.set_process_unhandled_key_input(true)

func show_menu(type = null):
	if not NetworkBridge.check_connection():
		return
	_layout_menu()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	Global.player.set_process(true)
	Global.player.set_physics_process(true)
	Global.player.set_process_input(false)
	Global.player.set_process_unhandled_key_input(false)

func _layout_menu():


	anchor_left = 0
	anchor_top = 0
	anchor_right = 0
	anchor_bottom = 0
	rect_size = Vector2(1280, 720)
	var viewport_size = get_viewport().get_visible_rect().size
	var ratio = min(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	rect_scale = Vector2(ratio, ratio)
	rect_position = (viewport_size - rect_size * ratio) * 0.5
	for child in get_children():
		if child.has_method("fit_in_parent"):
			child.fit_in_parent()

func _input(event):
	if parent.Flow.result_active:
		return
	if not NetworkBridge.check_connection():
		return
	if Input.is_action_just_pressed("ui_cancel"):
		if visible:
			hide_menu()
		else:
			show_menu()

func exit_to_level_select(type):
	_exit_group(true)

func exit_to_menu(type):
	_exit_group(false)

func _exit_group(level_select):
	if not NetworkBridge.check_connection():
		return
	hide_menu()
	parent.Flow.exit_to_menu(level_select)

func leave_game(type):
	hide_menu()
	set_process_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	for child in parent.Players.get_children():
		child.queue_free()
	
	parent.leave_server()
	get_tree().quit()
