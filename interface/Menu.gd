extends Control

onready var NetworkBridge = $"../NetworkBridge"

onready var parent = get_parent()
var previous_game_menu_pause_mode = Node.PAUSE_MODE_INHERIT
var quick_chat_active = false
var quick_chat_prior_open = false
var quick_chat_hidden_controls = {}
var native_panel_ratio = 1.0
var native_panel_base_sizes = {}

func _ready():
	get_viewport().connect("size_changed", self, "_layout_menu")
	_layout_menu()
	hide()
	set_process_input(false)

func hide_menu(type = null):
	if quick_chat_active:
		close_quick_chat()
		return
	_reset_hovered_buttons()
	hide()
	set_process_input(true)
	get_parent().Hint.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	Global.player.set_process(true)
	Global.player.set_physics_process(true)
	Global.player.set_process_input(true)
	Global.player.set_process_unhandled_key_input(true)

func show_menu(type = null):
	if not NetworkBridge.check_connection():
		return
	if quick_chat_active:
		close_quick_chat()
	_layout_menu()
	_reset_hovered_buttons()
	show()
	set_process_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	Global.player.set_process(true)
	Global.player.set_physics_process(true)
	Global.player.set_process_input(false)
	Global.player.set_process_unhandled_key_input(false)

func open_settings(_type = null):
	_reset_hovered_buttons()
	hide()
	set_process_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Global.player.set_process_input(false)
	Global.player.set_process_unhandled_key_input(false)
	var game_menu = Global.menu
	previous_game_menu_pause_mode = game_menu.pause_mode
	game_menu.pause_mode = Node.PAUSE_MODE_PROCESS
	game_menu.online_pause_settings = true
	game_menu.visible = true
	game_menu.menu[game_menu.START].show()
	game_menu._refresh_start_buttons()
	game_menu._on_Settings_Button_Pressed(game_menu.START, game_menu.menu[game_menu.START].get_child(1))

func close_settings():
	var game_menu = Global.menu
	game_menu._navigation_generation += 1
	game_menu.online_pause_settings = false
	game_menu.menu[game_menu.SETTINGS].hide()
	game_menu.get_node("Settings").hide()
	game_menu.menu[game_menu.START].hide()
	game_menu.active_menus = [game_menu.menu[game_menu.START]]
	game_menu.active_element = null
	game_menu.menu_changing = false
	game_menu.hide()
	game_menu.pause_mode = previous_game_menu_pause_mode
	show_menu()

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
	native_panel_ratio = max(0.01, ratio)
	for panel_name in ["ChatBox", "Stats"]:
		var panel = get_node_or_null(panel_name)
		if panel == null:
			continue
		if not native_panel_base_sizes.has(panel_name):
			native_panel_base_sizes[panel_name] = panel.rect_size
		panel.rect_scale = Vector2(1.0, 1.0) / native_panel_ratio
		panel.rect_size = native_panel_base_sizes[panel_name] * native_panel_ratio
		panel.set_size_ratio(native_panel_ratio)
	for child in get_children():
		if child.has_method("fit_in_parent"):
			child.fit_in_parent()
	var can_restart = NetworkBridge.is_world_authority()
	$Restart.visible = can_restart
	for node_name in ["OpenStats", "CloseStats", "Settings", "ExitLevelSelect", "ExitMenu", "Exit"]:
		var button = get_node(node_name)
		var base_x = {"Settings": 164.0, "OpenStats": 228.0, "CloseStats": 228.0, "ExitLevelSelect": 292.0, "ExitMenu": 356.0, "Exit": 420.0}[node_name]
		button.rect_position.x = base_x + (64.0 if can_restart else 0.0)

func _reset_hovered_buttons():
	for child in get_children():
		if child.has_method("button_enable") and child.enalbed:
			child.texture = child.idleTexture
	get_parent().Hint.hide()

func restart_mission(_type = null):
	if not NetworkBridge.is_world_authority():
		return
	hide_menu()
	parent.Flow.restart_mission()

func open_quick_chat():
	if quick_chat_active or visible or not NetworkBridge.check_connection() or parent.Flow.result_active:
		return
	if not is_instance_valid(Global.menu) or not Global.menu.in_game:
		return
	_layout_menu()
	quick_chat_active = true
	quick_chat_prior_open = $ChatBox.visible
	quick_chat_hidden_controls.clear()
	for child in get_children():
		if child == $ChatBox or not child is CanvasItem:
			continue
		quick_chat_hidden_controls[child] = child.visible
		child.hide()
	show()
	$ChatBox.open_chat(null)
	$ChatBox.lineEdit.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Global.player.set_process_input(false)
	Global.player.set_process_unhandled_key_input(false)
	set_process_input(true)

func close_quick_chat():
	if not quick_chat_active:
		return
	quick_chat_active = false
	$ChatBox.lineEdit.release_focus()
	if quick_chat_prior_open:
		$ChatBox.open_chat(null)
	else:
		$ChatBox.close_chat(null)
	for child in quick_chat_hidden_controls:
		if is_instance_valid(child):
			child.visible = quick_chat_hidden_controls[child]
	quick_chat_hidden_controls.clear()
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Global.player.set_process_input(true)
	Global.player.set_process_unhandled_key_input(true)

func _input(event):
	if quick_chat_active:
		if event.is_action_pressed("ui_cancel"):
			close_quick_chat()
			get_tree().set_input_as_handled()
		return
	if is_instance_valid(Global.menu) and Global.menu.online_pause_settings:
		if event.is_action_pressed("ui_cancel") and not Global.menu.wait_for_key:
			close_settings()
			get_tree().set_input_as_handled()
		return
	if parent.Flow.result_active:
		return
	if not NetworkBridge.check_connection():
		return
	if event.is_action_pressed("Open_Chat") and not visible:
		open_quick_chat()
		if quick_chat_active:
			get_tree().set_input_as_handled()
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
