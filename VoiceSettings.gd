extends PanelContainer

onready var voice = Global.get_node("Multiplayer/VoiceChat")
var volume
var enabled
var device
var push_to_talk
var binding
var volume_label
var device_names = []

func _ready():
	name = "VC"
	pause_mode = Node.PAUSE_MODE_PROCESS
	var host = get_parent().get_node("Host")
	add_stylebox_override("panel", host.get_stylebox("panel"))
	var box = VBoxContainer.new()
	box.name = "VBoxContainer"
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_constant_override("separation", 10)
	add_child(box)
	var header = Label.new()
	header.text = "Voice chat settings"
	header.align = Label.ALIGN_CENTER
	box.add_child(header)
	enabled = CheckBox.new()
	enabled.text = "<<"
	enabled.theme = host.get_node("VBoxContainer/useVoiceChat/TickEdit").theme
	enabled.pressed = voice.settings.enabled
	_row(box, "Enable Voice Chat:", enabled)
	_connect_description_tooltip(enabled.get_parent(), "Enable or disable voice chat for you. This does not enable or disable voice chat for other players.")
	enabled.connect("toggled", self, "_enabled_changed")
	volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 200
	volume.step = 1
	volume.value = voice.settings.volume
	volume_label = _row(box, "Global Volume: " + str(int(volume.value)) + "%", volume)
	volume.connect("value_changed", self, "_volume_changed")
	device = OptionButton.new()
	device.clip_text = true
	_row(box, "Voice Input:", device)
	device.connect("item_selected", self, "_device_changed")
	device.connect("pressed", self, "_refresh_devices")
	_refresh_devices()
	push_to_talk = CheckBox.new()
	push_to_talk.text = "<<"
	push_to_talk.theme = enabled.theme
	push_to_talk.pressed = voice.settings.push_to_talk
	_row(box, "Use Push-To-Talk:", push_to_talk)
	push_to_talk.connect("toggled", self, "_ptt_changed")
	binding = Button.new()
	binding.text = voice.binding_text()
	_row(box, "Push-To-Talk:", binding)
	binding.connect("pressed", self, "_bind_pressed")

func _row(box, title, control):
	var row = HBoxContainer.new()
	box.add_child(row)
	var label = Label.new()
	label.text = title
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(label)
	control.rect_min_size.x = 50 if control is CheckBox else 240
	row.add_child(control)
	return label

func _connect_description_tooltip(node, description):
	if node is Control:
		if not node.is_connected("mouse_entered", self, "_description_tooltip_entered"):
			node.connect("mouse_entered", self, "_description_tooltip_entered", [description])
		if not node.is_connected("mouse_exited", self, "_description_tooltip_exited"):
			node.connect("mouse_exited", self, "_description_tooltip_exited")
	for child in node.get_children():
		_connect_description_tooltip(child, description)

func _description_tooltip_entered(description):
	if not is_instance_valid(Global.menu) or not is_instance_valid(Global.menu.hover_info):
		return
	var hover = Global.menu.hover_info
	hover.get_node("Image").hide()
	hover.get_node("Name").hide()
	hover.get_node("Hint").show()
	hover.get_node("Hint").text = description
	hover.get_parent().rect_size = Vector2.ZERO
	hover.get_parent().raise()
	hover.get_parent().show()

func _description_tooltip_exited():
	if not is_instance_valid(Global.menu) or not is_instance_valid(Global.menu.hover_info):
		return
	var hover = Global.menu.hover_info
	hover.get_node("Name").show()
	hover.get_parent().hide()
	hover.get_parent().rect_size = Vector2.ZERO

func _volume_changed(value):
	voice.change_setting("volume", value)
	volume_label.text = "Global Volume: " + str(int(value)) + "%"

func _enabled_changed(value):
	voice.change_setting("enabled", value)

func _ptt_changed(value):
	voice.change_setting("push_to_talk", value)

func _refresh_devices():
	var names = voice.devices()
	if names == device_names:
		return
	device_names = names
	device.clear()
	for name in names:
		device.add_item(name)
	var selected = names.find(voice.settings.device)
	device.select(max(0, selected))

func _device_changed(index):
	if index >= 0 and index < device_names.size():
		voice.change_setting("device", device_names[index])

func _bind_pressed():
	voice.binding_active = true
	binding.text = "Press a key..."

func _input(event):
	if not voice.binding_active or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode != KEY_ESCAPE:
			voice.change_setting("binding", {"kind": "key", "code": event.scancode})
	elif event is InputEventMouseButton and event.pressed:
		voice.change_setting("binding", {"kind": "mouse", "code": event.button_index})
	else:
		return
	voice.binding_active = false
	binding.text = voice.binding_text()
	get_tree().set_input_as_handled()

func _process(_delta):
	if not is_visible_in_tree() and voice.binding_active:
		voice.binding_active = false
		binding.text = voice.binding_text()
