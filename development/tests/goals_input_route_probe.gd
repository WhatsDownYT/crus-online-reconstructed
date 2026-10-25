extends Node

var overlay_events = []

func _ready():
	call_deferred("run")

func _on_overlay_input(event):
	if event is InputEventMouseButton:
		overlay_events.append(event.button_index)

func run():
	yield(get_tree().create_timer(1.0), "timeout")
	var menu = Global.get_node("Menu")
	menu._on_Goals_Button_Pressed(menu.START, menu.menu[menu.START].get_child(7))
	yield(get_tree().create_timer(0.3), "timeout")
	var goals = menu.goals_screen
	goals.input_overlay.connect("gui_input", self, "_on_overlay_input")
	var point = goals._ui_point_to_scene(Vector2(100, 220))
	var wheel = InputEventMouseButton.new()
	wheel.button_index = BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = point
	wheel.global_position = point
	var before = goals.list_scroll.scroll_vertical
	Input.parse_input_event(wheel)
	yield(get_tree(), "idle_frame")
	print("GOALS_ROUTE point=", point, " overlay=", goals.input_overlay.rect_position, " scroll=", before, "/", goals.list_scroll.scroll_vertical, " events=", overlay_events)
	goals.list_scroll.scroll_vertical = 0
	goals.rect_scale = Vector2(1.5, 1.5)
	wheel.position = goals.get_global_transform_with_canvas().xform(point)
	wheel.global_position = wheel.position
	goals._input(wheel)
	print("GOALS_ROUTE scaled_scroll=", goals.list_scroll.scroll_vertical, " scale=", goals.rect_scale)
	print("GOALS_ROUTE audio bus=", goals.tap_player.bus, " index=", AudioServer.get_bus_index(goals.tap_player.bus), " volume=", goals.tap_player.volume_db)
	for index in range(AudioServer.bus_count):
		print("GOALS_ROUTE bus ", AudioServer.get_bus_name(index), " volume=", AudioServer.get_bus_volume_db(index), " muted=", AudioServer.is_bus_mute(index))
	get_tree().quit()
