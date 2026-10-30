extends Node

var ui_hidden = false
var active_player = null
var faded_controls = []
var view_hidden = false
var hidden_view_nodes = []
var hidden_target_nodes = []
var target_scan_time = 0.0

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS

func _input(event):
	if not event is InputEventKey or not event.pressed or event.echo or not _in_level():
		return
	if event.scancode == KEY_F2:
		ui_hidden = not ui_hidden
		if ui_hidden:
			_hide_ui()
			_hide_targets()
		else:
			_restore_ui()
			_restore_nodes(hidden_target_nodes)
		get_tree().set_input_as_handled()
	elif event.scancode == KEY_F3:
		view_hidden = not view_hidden
		if view_hidden:
			_hide_view()
		else:
			_restore_view()
		get_tree().set_input_as_handled()

func _process(delta):
	if not _in_level() or active_player != Global.player:
		_reset()
		if _in_level():
			active_player = Global.player
	elif ui_hidden:
		_hide_ui()
	if view_hidden and _in_level():
		_hide_view()
	if ui_hidden and _in_level():
		for entry in hidden_target_nodes:
			if is_instance_valid(entry[0]): entry[0].hide()
		target_scan_time += delta
		if target_scan_time >= 1.0:
			target_scan_time = 0.0
			_hide_targets()

func _in_level():
	return is_instance_valid(Global.player) and Global.player.is_inside_tree() and is_instance_valid(Global.menu) and Global.menu.in_game

func _hide_ui():
	var controls = []
	for path in ["UI", "Reticle", "Scope"]:
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
	if is_instance_valid(online) and is_instance_valid(online.Voice.meter_layer):
		for control in online.Voice.meter_layer.get_children():
			if control is Control: controls.append(control)
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

func _hide_view():
	_hide_view_node(Global.player.get("weapon"))
	_hide_view_node(Global.player.get_node_or_null("Grab_Hand"))

func _hide_targets():
	if is_instance_valid(Global.current_scene):
		_hide_target_icons(Global.current_scene)

func _hide_target_icons(node):
	if node is MeshInstance and node.name == "Objective_Indicator" and node.visible:
		_hide_node(node, hidden_target_nodes)
	if node is Sprite or node is Sprite3D or node is TextureRect:
		var image = node.texture
		if node.visible and is_instance_valid(image) and image.resource_path.to_lower().ends_with("/target.png"):
			_hide_node(node, hidden_target_nodes)
	for child in node.get_children():
		_hide_target_icons(child)

func _hide_view_node(node):
	_hide_node(node, hidden_view_nodes)

func _hide_node(node, nodes):
	if not is_instance_valid(node):
		return
	for entry in nodes:
		if entry[0] == node:
			node.hide()
			return
	nodes.append([node, node.visible])
	node.hide()

func _restore_view():
	_restore_nodes(hidden_view_nodes)

func _restore_nodes(nodes):
	for entry in nodes:
		if is_instance_valid(entry[0]):
			entry[0].visible = entry[1]
	nodes.clear()

func _reset():
	_restore_nodes(hidden_target_nodes)
	target_scan_time = 0.0
	if view_hidden:
		_restore_view()
	view_hidden = false
	if ui_hidden:
		_restore_ui()
	ui_hidden = false
	active_player = null
