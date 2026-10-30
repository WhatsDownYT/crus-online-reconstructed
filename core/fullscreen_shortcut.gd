extends Node

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS

func _input(event):
	if not event is InputEventKey or not event.pressed or event.echo or event.scancode != KEY_F11:
		return
	var game_menu = Global.get_node_or_null("Menu")
	var fullscreen = not Global.full_screen
	if game_menu != null:
		game_menu._on_Full_Screen_toggled(fullscreen)
		var checkbox = game_menu.get_node_or_null("Settings/GridContainer/PanelContainer5/CheckBox")
		if checkbox != null:
			checkbox.set_pressed_no_signal(fullscreen)
	else:
		OS.window_borderless = true
		OS.window_fullscreen = fullscreen
		Global.full_screen = fullscreen
		get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_VIEWPORT if fullscreen else SceneTree.STRETCH_MODE_DISABLED, SceneTree.STRETCH_ASPECT_KEEP, Vector2(Global.resolution[0], Global.resolution[1]))
	Global.save_settings()
	get_tree().set_input_as_handled()
