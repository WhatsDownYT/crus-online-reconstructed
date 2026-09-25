extends Node

var ui_hidden = false
var world_black = false
var active_player = null
var faded_controls = []
var screen_effect = null
var screen_effect_visible = false
var black_layer:CanvasLayer
var black_rect:ColorRect

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	black_layer = CanvasLayer.new()
	black_layer.layer = -1
	black_layer.name = "CaptureBlackLayer"
	add_child(black_layer)
	black_rect = ColorRect.new()
	black_rect.name = "CaptureBlack"
	black_rect.color = Color(0, 0, 0, 1)
	black_rect.anchor_right = 1.0
	black_rect.anchor_bottom = 1.0
	black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_rect.hide()
	black_layer.add_child(black_rect)

func _input(event):
	if not event is InputEventKey or not event.pressed or event.echo or not _in_level():
		return
	if event.scancode == KEY_F8:
		ui_hidden = not ui_hidden
		if ui_hidden:
			_hide_ui()
		else:
			_restore_ui()
		get_tree().set_input_as_handled()
	elif event.scancode == KEY_F9:
		world_black = not world_black
		black_rect.visible = world_black
		_sync_screen_effect()
		get_tree().set_input_as_handled()

func _process(_delta):
	if not _in_level() or active_player != Global.player:
		_reset()
		if _in_level():
			active_player = Global.player
	elif ui_hidden:
		_hide_ui()
	if world_black:
		_sync_screen_effect()

func _in_level():
	return is_instance_valid(Global.player) and Global.player.is_inside_tree() and is_instance_valid(Global.menu) and Global.menu.in_game

func _hide_ui():
	var controls = []
	for path in ["UI", "Reticle", "Scope", "Grab_Hand"]:
		var control = Global.player.get_node_or_null(path)
		if is_instance_valid(control):
			controls.append(control)
	if is_instance_valid(Global.menu):
		controls.append(Global.menu)
	if is_instance_valid(Global.border):
		controls.append(Global.border)
	var online = Global.get_node_or_null("Multiplayer")
	if is_instance_valid(online):
		for path in ["Menu", "Hint", "SyncLoad", "Debug"]:
			var control = online.get_node_or_null(path)
			if is_instance_valid(control):
				controls.append(control)
	var death_screen = Global.get_node_or_null("DeathScreen")
	if is_instance_valid(death_screen):
		controls.append(death_screen)
	for control in controls:
		var found = false
		for entry in faded_controls:
			if entry[0] == control:
				found = true
				break
		if not found:
			faded_controls.append([control, control.modulate.a])
		control.modulate.a = 0.0

func _restore_ui():
	for entry in faded_controls:
		if is_instance_valid(entry[0]):
			entry[0].modulate.a = entry[1]
	faded_controls.clear()

func _sync_screen_effect():
	if world_black:
		if not is_instance_valid(screen_effect):
			screen_effect = Global.player.get_node_or_null("Shader_Screen")
			if is_instance_valid(screen_effect):
				screen_effect_visible = screen_effect.visible
		if is_instance_valid(screen_effect):
			screen_effect.hide()
	elif is_instance_valid(screen_effect):
		screen_effect.visible = screen_effect_visible
		screen_effect = null

func _reset():
	if ui_hidden:
		_restore_ui()
	ui_hidden = false
	world_black = false
	black_rect.hide()
	_sync_screen_effect()
	active_player = null
