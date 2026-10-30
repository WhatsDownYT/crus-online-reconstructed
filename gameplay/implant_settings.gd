extends PanelContainer

onready var Multiplayer = Global.get_node("Multiplayer")
onready var implant_scroll = $HBoxContainer/ImplantsController/AllowedImplantsList
onready var controls = $HBoxContainer/VBoxContainer
onready var preset_picker = $HBoxContainer/VBoxContainer/PresetSlot/PresetPicker
onready var status_label = $HBoxContainer/VBoxContainer/StatusSlot/StatusLabel

var updated = false
var bannedImplants = {}
var displayed = []
var implant_buttons = []
var last_state = ""
var kind = "implants"
var entries = []
var category_buttons = []
var hovered_index = -1

func _ready():
	controls.get_node("Button").connect("pressed", self, "save_preset")
	controls.get_node("DeletePreset").connect("pressed", self, "delete_preset")
	preset_picker.connect("item_selected", self, "load_preset")
	var controller = $HBoxContainer/ImplantsController
	controller.rect_min_size.x = 334
	controller.size_flags_horizontal = SIZE_FILL
	controls.size_flags_horizontal = SIZE_EXPAND_FILL
	controls.move_child(controls.get_node("Button"), controls.get_node("DeletePreset").get_index())
	controls.move_child(controls.get_node("StatusSlot"), controls.get_node("Button3").get_index())
	var spacer = Control.new()
	spacer.name = "BottomSpacer"
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	controls.add_child(spacer)
	controls.move_child(spacer, controls.get_node("Button3").get_index())

	controller.get_node("AllowedImplantsLabel").hide()
	var categories = HBoxContainer.new()
	categories.name = "Categories"
	controller.add_child(categories)
	controller.move_child(categories, 0)
	for label in ["Implants", "Weapons"]:
		var button = Button.new()
		button.text = label
		button.rect_min_size.x = 160
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.connect("pressed", self, "select_kind", [label.to_lower()])
		categories.add_child(button)
		category_buttons.append(button)
	category_buttons[0].pressed = true

func can_edit():
	return not Multiplayer.NetworkBridge.check_connection() or Multiplayer.NetworkBridge.is_world_authority()

func select_kind(value):
	if kind == value:
		category_buttons[0].pressed = kind == "implants"
		category_buttons[1].pressed = kind == "weapons"
		return
	hide_implant_hover()
	kind = value
	updated = false
	last_state = ""
	update()

func update():
	if updated: return
	updated = true
	var old_grid = implant_scroll.get_node_or_null("BanGrid")
	if old_grid != null:
		implant_scroll.remove_child(old_grid)
		old_grid.queue_free()
	displayed.clear()
	implant_buttons.clear()
	entries.clear()
	controls.get_node("Label").text = "Weapon rules" if kind == "weapons" else "Implant rules"
	status_label.text = ""
	category_buttons[0].pressed = kind == "implants"
	category_buttons[1].pressed = kind == "weapons"
	if kind == "weapons":
		entries = Multiplayer.weapon_ban_entries()
	else:
		for implant in Global.implants.IMPLANTS:
			if implant.i_name == "House": continue
			entries.append({"key": implant.i_name, "name": implant.i_name, "texture": implant.texture, "implant": implant})
	var grid = GridContainer.new()
	grid.name = "BanGrid"
	grid.columns = 5
	grid.add_constant_override("hseparation", 0)
	grid.add_constant_override("vseparation", 0)
	implant_scroll.add_child(grid)
	for entry in entries:
		var index = displayed.size()
		displayed.append(entry.key)
		var button = TextureButton.new()
		button.name = "Entry" + str(index)
		button.texture_normal = entry.texture
		button.expand = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.rect_min_size = Vector2(64, 64)
		button.focus_mode = Control.FOCUS_ALL
		button.connect("pressed", self, "toggle_implant", [index])
		button.connect("mouse_entered", self, "hover_implant", [index])
		button.connect("mouse_exited", self, "hide_implant_hover")
		grid.add_child(button)
		implant_buttons.append(button)
	implant_scroll.scroll_vertical = 0
	refresh_presets()
	refresh()

func _known(entry):
	if kind == "weapons":
		return entry.index < Global.WEAPONS_UNLOCKED.size() and Global.WEAPONS_UNLOCKED[entry.index]
	var equipment = Global.menu.get_node("Character_Menu/Character_Container")
	return not equipment._implant_is_undiscovered(entry.implant)

func _details(entry):
	if not _known(entry): return "???\n???"
	return entry.name + "\n" + entry.description if kind == "weapons" else _implant_details(entry.implant)

func _ban_key():
	return "bannedWeapons" if kind == "weapons" else "bannedImplants"

func _preset_key():
	return "weaponBanPresets" if kind == "weapons" else "implantPresets"

func _implant_details(implant):
	var slot = "Head" if implant.head else ("Chest" if implant.torso else ("Arms" if implant.arms else "Legs"))
	var details = implant.i_name + "\nSlot: " + slot + "\n" + implant.explanation
	if implant.armor != 1:
		details += "\nArmor: " + str(100 - implant.armor * 100) + "%"
	if implant.speed_bonus != 0:
		details += "\nSpeed: " + str(implant.speed_bonus)
	if implant.jump_bonus != 0:
		details += "\nJump bonus: " + str(implant.jump_bonus)
	return details

func hover_implant(index):
	if index < 0 or index >= entries.size() or not is_instance_valid(Global.menu.hover_info): return
	hovered_index = index
	var entry = entries[index]
	var known = _known(entry)
	var hover = Global.menu.hover_info
	hover.get_node("Name").text = (entry.name + (" (Banned)" if entry.key in bannedImplants else "")) if known else "???"
	hover.get_node("Name").show()
	hover.get_node("Image").texture = entry.texture
	hover.get_node("Image").show()
	hover.get_node("Hint").text = _details(entry).trim_prefix(entry.name + "\n") if known else "???"
	hover.get_node("Hint").show()
	hover.get_parent().rect_size = Vector2.ZERO
	hover.get_parent().raise()
	hover.get_parent().show()

func hide_implant_hover():
	hovered_index = -1
	if not is_instance_valid(Global.menu) or not is_instance_valid(Global.menu.hover_info): return
	Global.menu.hover_info.get_parent().hide()
	Global.menu.hover_info.get_parent().rect_size = Vector2.ZERO

func refresh():
	if not updated:
		return
	var bans = Multiplayer.config.get(_ban_key(), []) if can_edit() else Multiplayer.hostSettings.get(_ban_key(), [])
	var state = kind + str(bans) + str(can_edit()) + str(Global.WEAPONS_UNLOCKED) + str(Global.implants.purchased_implants)
	if state == last_state:
		return
	last_state = state
	bannedImplants.clear()
	for index in range(displayed.size()):
		var banned = displayed[index] in bans
		if banned:
			bannedImplants[displayed[index]] = index
		implant_buttons[index].modulate = Color(1, 0.2, 0.2) if banned else Color.white
		implant_buttons[index].disabled = not can_edit()
		implant_buttons[index].hint_tooltip = _details(entries[index]) + ("\nBanned by host" if banned else "\nAllowed")
	for name in ["Button", "DeletePreset", "Button3", "Button4"]:
		controls.get_node(name).disabled = not can_edit()
	controls.get_node("LineEdit").editable = can_edit()
	preset_picker.disabled = not can_edit() or preset_picker.get_item_count() < 2
	if not is_visible_in_tree(): hovered_index = -1
	elif hovered_index >= 0: hover_implant(hovered_index)

func apply_bans(bans):
	if not can_edit() or not bans is Array:
		return
	var valid = []
	for name in bans:
		if name in displayed and not name in valid:
			valid.append(name)
	Multiplayer.config[_ban_key()] = valid
	_save_config()
	Multiplayer.apply_host_settings()
	preset_picker.select(0)
	refresh()

func toggle_implant(index):
	if not can_edit() or index < 0 or index >= displayed.size():
		return
	var bans = Multiplayer.config.get(_ban_key(), []).duplicate()
	var name = displayed[index]
	if name in bans:
		bans.erase(name)
		$Equip.play()
	else:
		bans.append(name)
		$Unequip.play()
	apply_bans(bans)

func ban_all():
	apply_bans(displayed)

func allow_all():
	apply_bans([])

func refresh_presets(select_name = ""):
	if not Multiplayer.config.has(_preset_key()): Multiplayer.config[_preset_key()] = {}
	var picker = preset_picker
	picker.clear()
	picker.add_item("Select preset")
	var names = Multiplayer.config[_preset_key()].keys()
	names.sort()
	for name in names:
		picker.add_item(name)
	picker.select(0)
	if select_name in names:
		picker.select(names.find(select_name) + 1)
	picker.disabled = not can_edit() or names.empty()

func save_preset():
	var name = controls.get_node("LineEdit").text.strip_edges()
	if not can_edit() or name.empty():
		status_label.text = "Enter a preset name"
		return
	Multiplayer.config[_preset_key()][name] = Multiplayer.config.get(_ban_key(), []).duplicate()
	_save_config()
	refresh_presets(name)
	status_label.text = "Preset saved"

func load_preset(index):
	if not can_edit() or index <= 0:
		return
	var name = preset_picker.get_item_text(index)
	if not Multiplayer.config[_preset_key()].has(name):
		return
	apply_bans(Multiplayer.config[_preset_key()][name])
	preset_picker.select(index)
	status_label.text = "Preset loaded"

func delete_preset():
	if not can_edit() or preset_picker.get_selected() <= 0:
		status_label.text = "Choose a preset"
		return
	var name = preset_picker.get_item_text(preset_picker.get_selected())
	Multiplayer.config[_preset_key()].erase(name)
	_save_config()
	refresh_presets()
	status_label.text = "Preset deleted"

func _save_config():
	preload("res://MOD_CONTENT/CruS Online/core/profile_store.gd").new().save_data("config.save", Multiplayer.config)
