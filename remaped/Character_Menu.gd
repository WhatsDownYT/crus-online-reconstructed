extends HBoxContainer

var EQUIPMENT_BUTTONS:Array
enum {HEAD, TORSO, LEG, ARM}
const GRID_SIZE = 64
const NAVIGATION_SLOT = GRID_SIZE - 1
const PAGE_SLOT_COUNT = GRID_SIZE - 1
const TRANSITION_BATCH = 4
const ONLINE_IMPLANTS = ["Pneumatic Merit Pump", "Surveillance Eyecam", "Surveillance Eyecam PRO MAX", "Military Camouflage+", "Stealth Suit+", "ZZzzz Special Sedative Grenade+", "First Aid Kit+", "Cursed Torch+", "Augmented Arms+"]
const ONLINE_EXTENSION_BASES = {
	"Military Camouflage+": "Military Camouflage",
	"Stealth Suit+": "Stealth Suit",
	"ZZzzz Special Sedative Grenade+": "ZZzzz Special Sedative Grenade",
	"First Aid Kit+": "First Aid Kit",
	"Cursed Torch+": "Cursed Torch",
	"Augmented Arms+": "Augmented arms"
}
const EMPTY_TEXTURE = preload("res://Textures/Menu/Empty_Slot.png")
const MYSTERY_TEXTURE = preload("res://Textures/Menu/mystery.png")
const NEXT_LEVEL_TEXTURE = preload("res://Textures/Menu/Next_Level.png")
var IMPLANTS
var confirmed = false
var cancel = false
var hover_info
var current_page = 0
var page_transitioning = false
var button_implant_indices:Array = []
var navigation_button = null

func _ready():
	yield (get_tree(), "idle_frame")
	$ConfirmationDialog.get_cancel().connect("pressed", self, "_on_Cancel_Pressed")
	$TextureRect / Money.text = "$" + str(Global.money)
	$TextureRect / Arm_Button.connect("pressed", self, "_slot_button_pressed", [ARM])
	$TextureRect / Arm_Button.connect("mouse_entered", self, "_slot_button_entered", [ARM])
	$TextureRect / Leg_Button.connect("pressed", self, "_slot_button_pressed", [LEG])
	$TextureRect / Leg_Button.connect("mouse_entered", self, "_slot_button_entered", [LEG])
	$TextureRect / Head_Button.connect("pressed", self, "_slot_button_pressed", [HEAD])
	$TextureRect / Head_Button.connect("mouse_entered", self, "_slot_button_entered", [HEAD])
	$TextureRect / Torso_Button.connect("pressed", self, "_slot_button_pressed", [TORSO])
	$TextureRect / Torso_Button.connect("mouse_entered", self, "_slot_button_entered", [TORSO])
	hover_info = get_parent().get_parent().get_node("Hover_Panel/Hover_Info")
	IMPLANTS = Global.implants.IMPLANTS
	for b in range(GRID_SIZE):
		var new_button = TextureButton.new()
		$Equip_Grid.add_child(new_button)
		new_button.name = "n/a"
		new_button.texture_normal = EMPTY_TEXTURE
		new_button.texture_disabled = EMPTY_TEXTURE
		new_button.rect_size = Vector2(64, 64)
		new_button.rect_pivot_offset = Vector2(32, 32)
		new_button.expand = true
		new_button.connect("pressed", self, "_on_implant_pressed", [b])
		new_button.connect("mouse_entered", self, "_on_mouse_entered", [b])
		new_button.connect("mouse_exited", self, "_on_mouse_exited", [b])
		new_button.size_flags_horizontal = SIZE_EXPAND_FILL
		new_button.size_flags_vertical = SIZE_EXPAND_FILL
		new_button.stretch_mode = TextureButton.STRETCH_SCALE
		EQUIPMENT_BUTTONS.append(new_button)
		button_implant_indices.append(-1)
	navigation_button = EQUIPMENT_BUTTONS[NAVIGATION_SLOT]
	_populate_page(current_page)

func _page_implant_indices(page):
	var indices = []
	for i in range(IMPLANTS.size()):
		var online_implant = ONLINE_IMPLANTS.has(IMPLANTS[i].i_name)
		if (page == 1 and online_implant) or (page == 0 and not online_implant):
			indices.append(i)
	return indices

func _set_button_empty(slot):
	button_implant_indices[slot] = -1
	var button = EQUIPMENT_BUTTONS[slot]
	button.name = "n/a"
	button.texture_normal = EMPTY_TEXTURE
	button.texture_disabled = EMPTY_TEXTURE
	button.modulate = Color(1, 1, 1, 1)
	button.rect_scale = Vector2(1, 1)
	button.disabled = true if page_transitioning else false

func _set_navigation_transition_empty():
	if not is_instance_valid(navigation_button):
		return
	button_implant_indices[NAVIGATION_SLOT] = -1
	navigation_button.name = "ImplantPageNavigation"
	navigation_button.texture_normal = EMPTY_TEXTURE
	navigation_button.texture_disabled = EMPTY_TEXTURE
	navigation_button.modulate = Color(1, 1, 1, 1)
	navigation_button.rect_pivot_offset = navigation_button.rect_size * 0.5
	navigation_button.rect_scale = Vector2(1, 1)
	navigation_button.disabled = true

func _set_navigation_button():
	if not is_instance_valid(navigation_button):
		return
	button_implant_indices[NAVIGATION_SLOT] = -1
	navigation_button.name = "Original Implants" if current_page == 1 else "Online Implants"
	navigation_button.texture_normal = NEXT_LEVEL_TEXTURE
	navigation_button.texture_disabled = NEXT_LEVEL_TEXTURE
	navigation_button.modulate = Color(1, 1, 1, 1)
	navigation_button.rect_pivot_offset = navigation_button.rect_size * 0.5
	navigation_button.rect_scale = Vector2(-1, 1) if current_page == 1 else Vector2(1, 1)
	navigation_button.disabled = page_transitioning

func _extension_base_name(implant):
	return ONLINE_EXTENSION_BASES.get(implant.i_name, "")

func _find_implant_by_name(implant_name):
	for implant in IMPLANTS:
		if implant.i_name == implant_name:
			return implant
	return null

func _extension_base_is_discovered(implant):
	var base_name = _extension_base_name(implant)
	if base_name == "":
		return true
	var base_implant = _find_implant_by_name(base_name)
	if base_implant == null:
		return false
	return not base_implant.hidden or Global.implants.purchased_implants.find(base_name) != -1

func _extension_base_is_owned(implant):
	var base_name = _extension_base_name(implant)
	return base_name == "" or Global.implants.purchased_implants.find(base_name) != -1

func _implant_is_undiscovered(implant):
	if implant.hidden and Global.implants.purchased_implants.find(implant.i_name) == -1:
		return true
	return not _extension_base_is_discovered(implant)

func _set_implant_button(slot, implant_index):
	button_implant_indices[slot] = implant_index
	var button = EQUIPMENT_BUTTONS[slot]
	var implant = IMPLANTS[implant_index]
	button.name = implant.i_name
	button.texture_normal = implant.texture
	button.texture_disabled = implant.texture
	button.modulate = Color(1, 1, 1, 1)
	button.rect_scale = Vector2(1, 1)
	button.disabled = page_transitioning
	if _implant_is_undiscovered(implant):
		button.texture_normal = MYSTERY_TEXTURE
		button.texture_disabled = MYSTERY_TEXTURE
		button.modulate = Color(1, 0, 0)
	elif not _extension_base_is_owned(implant) or Global.implants.purchased_implants.find(implant.i_name) == -1:
		button.modulate = Color(1, 0, 0)
	if _implant_is_equipped(implant) and _extension_base_is_owned(implant):
		button.modulate = Color(0.5, 0.5, 0.5)
	if not _implant_is_undiscovered(implant) and Global.get_node("Multiplayer").is_implant_banned(implant.i_name):
		button.modulate = Color(1, 0.2, 0.2)

func _implant_is_equipped(implant):
	return Global.implants.head_implant == implant or Global.implants.torso_implant == implant or Global.implants.leg_implant == implant or Global.implants.arm_implant == implant

func _populate_page(page):
	current_page = page
	var indices = _page_implant_indices(page)
	for slot in range(PAGE_SLOT_COUNT):
		if slot < indices.size():
			_set_implant_button(slot, indices[slot])
		else:
			_set_button_empty(slot)
	_set_navigation_button()

func _play_page_transition_sound(opening):
	var root = get_parent().get_parent()
	var player = root.get_node("SFX/Open" if opening else "SFX/Close")
	if opening:
		player.pitch_scale = 0.43 + rand_range(-0.3, 0.1)
	else:
		player.pitch_scale = 1 + rand_range(-0.3, 0.3)
	player.play()

func _change_page(page):
	if page_transitioning:
		return
	page_transitioning = true
	hover_info.get_parent().hide()
	for button in EQUIPMENT_BUTTONS:
		button.disabled = true
	_set_navigation_transition_empty()
	var transition_count = 0
	for slot in range(PAGE_SLOT_COUNT - 1, -1, -1):
		_set_button_empty(slot)
		transition_count += 1
		if transition_count % (TRANSITION_BATCH * 2) == 1:
			_play_page_transition_sound(false)
		if slot % TRANSITION_BATCH == 0:
			yield (get_tree(), "idle_frame")
	current_page = page
	var indices = _page_implant_indices(page)
	transition_count = 0
	for slot in range(PAGE_SLOT_COUNT):
		if slot < indices.size():
			_set_implant_button(slot, indices[slot])
		else:
			_set_button_empty(slot)
		transition_count += 1
		if transition_count % (TRANSITION_BATCH * 3) == 1:
			_play_page_transition_sound(true)
		if slot % TRANSITION_BATCH == TRANSITION_BATCH - 1:
			yield (get_tree(), "idle_frame")
	_set_navigation_button()
	page_transitioning = false
	update_buttons()

func clear_equips():
	Global.implants.head_implant = Global.implants.empty_implant
	Global.implants.leg_implant = Global.implants.empty_implant
	Global.implants.arm_implant = Global.implants.empty_implant
	Global.implants.torso_implant = Global.implants.empty_implant
	$TextureRect / Head_Button.texture_normal = EMPTY_TEXTURE
	$TextureRect / Torso_Button.texture_normal = EMPTY_TEXTURE
	$TextureRect / Leg_Button.texture_normal = EMPTY_TEXTURE
	$TextureRect / Arm_Button.texture_normal = EMPTY_TEXTURE
	update_buttons()

func _slot_button_pressed(type):
	match type:
		HEAD:
			if Global.implants.head_implant == Global.implants.empty_implant:
				return
			$Unequip.play()
			hover_info.get_parent().hide()
			Global.implants.head_implant = Global.implants.empty_implant
			$TextureRect / Head_Button.texture_normal = EMPTY_TEXTURE
		TORSO:
			if Global.implants.torso_implant == Global.implants.empty_implant:
				return
			$Unequip.play()
			Global.implants.torso_implant = Global.implants.empty_implant
			$TextureRect / Torso_Button.texture_normal = EMPTY_TEXTURE
		LEG:
			if Global.implants.leg_implant == Global.implants.empty_implant:
				return
			$Unequip.play()
			Global.implants.leg_implant = Global.implants.empty_implant
			$TextureRect / Leg_Button.texture_normal = EMPTY_TEXTURE
		ARM:
			if Global.implants.arm_implant == Global.implants.empty_implant:
				return
			$Unequip.play()
			Global.implants.arm_implant = Global.implants.empty_implant
			$TextureRect / Arm_Button.texture_normal = EMPTY_TEXTURE
	update_buttons()

func _slot_button_entered(type):
	var implant = null
	match type:
		HEAD:
			implant = Global.implants.head_implant
		TORSO:
			implant = Global.implants.torso_implant
		ARM:
			implant = Global.implants.arm_implant
		LEG:
			implant = Global.implants.leg_implant
	if implant != null and implant != Global.implants.empty_implant:
		_show_implant_info(IMPLANTS.find(implant))

func update_buttons():
	if page_transitioning:
		return
	for slot in range(PAGE_SLOT_COUNT):
		var implant_index = button_implant_indices[slot]
		if implant_index >= 0 and implant_index < IMPLANTS.size():
			_set_implant_button(slot, implant_index)
		else:
			_set_button_empty(slot)
	_set_navigation_button()
	$TextureRect/Head_Button.texture_normal = Global.implants.head_implant.texture
	$TextureRect/Torso_Button.texture_normal = Global.implants.torso_implant.texture
	$TextureRect/Arm_Button.texture_normal = Global.implants.arm_implant.texture
	$TextureRect/Leg_Button.texture_normal = Global.implants.leg_implant.texture

func _show_navigation_info():
	hover_info.get_node("Image").hide()
	hover_info.get_node("Name").show()
	hover_info.get_parent().raise()
	hover_info.get_node("Name").text = "Original Implants" if current_page == 1 else "Online Implants"
	hover_info.get_node("Hint").text = ""
	hover_info.get_node("Hint").hide()
	hover_info.get_parent().rect_size = Vector2.ZERO
	hover_info.get_parent().show()

func _show_implant_info(i):
	if i < 0 or i >= IMPLANTS.size():
		return
	if _implant_is_undiscovered(IMPLANTS[i]):
		hover_info.get_node("Image").show()
		hover_info.get_parent().raise()
		hover_info.get_node("Name").text = "???"
		hover_info.get_node("Hint").text = "Somewhere in this world something is waiting for you."
		hover_info.get_node("Image").texture = MYSTERY_TEXTURE
		hover_info.get_node("Hint").show()
		hover_info.get_parent().show()
		return
	if Global.get_node("Multiplayer").is_implant_banned(IMPLANTS[i].i_name):
		hover_info.get_node("Name").text = IMPLANTS[i].i_name + " (Banned)"
		hover_info.get_node("Hint").text = "This implant is disabled by the host."
		hover_info.get_node("Hint").show()
		hover_info.get_node("Image").texture = IMPLANTS[i].texture
		hover_info.get_node("Image").show()
		hover_info.get_parent().show()
		return
	hover_info.get_node("Image").show()
	hover_info.get_parent().raise()
	hover_info.get_node("Name").text = IMPLANTS[i].i_name
	hover_info.get_node("Image").texture = IMPLANTS[i].texture
	var infotext = IMPLANTS[i].explanation
	hover_info.get_node("Hint").text = ""
	if IMPLANTS[i].head:
		hover_info.get_node("Hint").text += "Slot: Head\n"
	if IMPLANTS[i].torso:
		hover_info.get_node("Hint").text += "Slot: Chest\n"
	if IMPLANTS[i].legs:
		hover_info.get_node("Hint").text += "Slot: Legs\n"
	if IMPLANTS[i].arms:
		hover_info.get_node("Hint").text += "Slot: Arms\n"
	if Global.implants.purchased_implants.find(IMPLANTS[i].i_name) == -1:
		hover_info.get_node("Hint").text += "$" + str(IMPLANTS[i].price) + "\n"
	hover_info.get_node("Hint").show()
	hover_info.get_node("Hint").text += infotext + "\n"
	if IMPLANTS[i].armor != 1:
		hover_info.get_node("Hint").text += "Armor: " + str(100 - IMPLANTS[i].armor * 100, "%") + "\n"
	if IMPLANTS[i].speed_bonus != 0:
		hover_info.get_node("Hint").text += "Speed: " + str(IMPLANTS[i].speed_bonus) + "\n"
	if IMPLANTS[i].jump_bonus != 0:
		hover_info.get_node("Hint").text += "Jump bonus: " + str(IMPLANTS[i].jump_bonus) + "\n"
	hover_info.get_parent().show()

func _on_navigation_mouse_entered():
	if page_transitioning:
		return
	_show_navigation_info()

func _on_navigation_mouse_exited():
	hover_info.get_node("Image").hide()
	hover_info.get_parent().hide()

func _on_navigation_pressed():
	if page_transitioning:
		return
	var transition = _change_page(0 if current_page == 1 else 1)
	if transition is GDScriptFunctionState:
		yield (transition, "completed")

func _on_mouse_entered(slot):
	if page_transitioning:
		return
	if slot == NAVIGATION_SLOT:
		_show_navigation_info()
		return
	var implant_index = button_implant_indices[slot]
	if implant_index >= 0:
		_show_implant_info(implant_index)

func _on_mouse_exited(slot):
	hover_info.get_node("Image").hide()
	hover_info.get_parent().hide()

func _on_implant_pressed(slot):
	if page_transitioning:
		return
	if slot == NAVIGATION_SLOT:
		var navigation = _on_navigation_pressed()
		if navigation is GDScriptFunctionState:
			yield (navigation, "completed")
		return
	var i = button_implant_indices[slot]
	if i < 0 or i >= IMPLANTS.size():
		return
	if Global.get_node("Multiplayer").is_implant_banned(IMPLANTS[i].i_name):
		_show_implant_info(i)
		return
	if _implant_is_undiscovered(IMPLANTS[i]):
		return
	if not _extension_base_is_owned(IMPLANTS[i]):
		cancel = false
		confirmed = false
		var base_name = _extension_base_name(IMPLANTS[i])
		$ConfirmationDialog.popup(Rect2(get_global_mouse_position(), Vector2(256, 128)))
		$ConfirmationDialog.dialog_text = "You cannot purchase " + IMPLANTS[i].i_name + " until " + base_name + " has been purchased."
		while confirmed == false and cancel == false:
			yield (get_tree(), "idle_frame")
		confirmed = false
		cancel = false
		return
	if Global.implants.purchased_implants.find(IMPLANTS[i].i_name) == -1:
		cancel = false
		if Global.money >= IMPLANTS[i].price:
			$ConfirmationDialog.popup(Rect2(get_global_mouse_position(), Vector2(256, 128)))
			$ConfirmationDialog.dialog_text = "Do you want to purchase " + IMPLANTS[i].i_name + " for $" + str(IMPLANTS[i].price) + "?"
			while confirmed == false and cancel == false:
				yield (get_tree(), "idle_frame")
			confirmed = false
			if cancel == true:
				cancel = false
				return
			cancel = false
			var m = Global.money
			Global.money -= IMPLANTS[i].price
			if Global.money < 0:
				Global.money = m
				return
			if IMPLANTS[i].i_name == "House":
				Global.BONUS_UNLOCK.append("House")
			$TextureRect / Money.text = str("$", Global.money)
			Global.implants.purchased_implants.append(IMPLANTS[i].i_name)
			Global.save_game()
			update_buttons()
		return
	$Equip.play()
	if IMPLANTS[i].head:
		if Global.implants.head_implant != Global.implants.empty_implant:
			_slot_button_pressed(HEAD)
		Global.implants.head_implant = IMPLANTS[i]
		$TextureRect / Head_Button.texture_normal = IMPLANTS[i].texture
	elif IMPLANTS[i].torso:
		if Global.implants.torso_implant != Global.implants.empty_implant:
			_slot_button_pressed(TORSO)
		Global.implants.torso_implant = IMPLANTS[i]
		$TextureRect / Torso_Button.texture_normal = IMPLANTS[i].texture
	elif IMPLANTS[i].legs:
		if Global.implants.leg_implant != Global.implants.empty_implant:
			_slot_button_pressed(LEG)
		Global.implants.leg_implant = IMPLANTS[i]
		$TextureRect / Leg_Button.texture_normal = IMPLANTS[i].texture
	elif IMPLANTS[i].arms:
		if Global.implants.arm_implant != Global.implants.empty_implant:
			_slot_button_pressed(ARM)
		Global.implants.arm_implant = IMPLANTS[i]
		$TextureRect / Arm_Button.texture_normal = IMPLANTS[i].texture
	update_buttons()

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		cancel = true

func _on_ConfirmationDialog_confirmed():
	confirmed = true

func _on_Cancel_Pressed():
	cancel = true
